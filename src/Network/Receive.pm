#########################################################################
#  OpenKore - Server message parsing
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Server message parsing
#
# This class is responsible for parsing messages that are sent by the RO
# server to Kore. Information in the messages are stored in global variables
# (in the module Globals).
#
# Please also read <a href="http://wiki.openkore.com/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::Receive;

use strict;
use Exporter;
use Network::PacketParser; # import
use base qw(Network::PacketParser);
use utf8;
use Carp::Assert;
use Scalar::Util;
use Socket qw(inet_aton inet_ntoa);

use AI;
use Globals;
use Field;
#use Settings;
use Log qw(message warning error debug);
use FileParsers qw(updateMonsterLUT updateNPCLUT);
use I18N qw(bytesToString stringToBytes);
use Interface;
use Network;
use Network::MessageTokenizer;
use Misc;
use Plugins;
use Utils;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;

our %EXPORT_TAGS = (
	actor_type => [qw(PC_TYPE NPC_TYPE ITEM_TYPE SKILL_TYPE UNKNOWN_TYPE NPC_MOB_TYPE NPC_EVT_TYPE NPC_PET_TYPE NPC_HO_TYPE NPC_MERSOL_TYPE
						NPC_ELEMENTAL_TYPE)],
	connection => [qw(REFUSE_INVALID_ID REFUSE_INVALID_PASSWD REFUSE_ID_EXPIRED ACCEPT_ID_PASSWD REFUSE_NOT_CONFIRMED REFUSE_INVALID_VERSION
						REFUSE_BLOCK_TEMPORARY REFUSE_BILLING_NOT_READY REFUSE_NONSAKRAY_ID_BLOCKED REFUSE_BAN_BY_DBA 
						REFUSE_EMAIL_NOT_CONFIRMED REFUSE_BAN_BY_GM REFUSE_TEMP_BAN_FOR_DBWORK REFUSE_SELF_LOCK REFUSE_NOT_PERMITTED_GROUP
						REFUSE_WAIT_FOR_SAKRAY_ACTIVE REFUSE_NOT_CHANGED_PASSWD REFUSE_BLOCK_INVALID REFUSE_WARNING REFUSE_NOT_OTP_USER_INFO
						REFUSE_OTP_AUTH_FAILED REFUSE_SSO_AUTH_FAILED REFUSE_NOT_ALLOWED_IP_ON_TESTING REFUSE_OVER_BANDWIDTH
						REFUSE_OVER_USERLIMIT REFUSE_UNDER_RESTRICTION REFUSE_BY_OUTER_SERVER REFUSE_BY_UNIQUESERVER_CONNECTION
						REFUSE_BY_AUTHSERVER_CONNECTION REFUSE_BY_BILLSERVER_CONNECTION REFUSE_BY_AUTH_WAITING REFUSE_DELETED_ACCOUNT
						REFUSE_ALREADY_CONNECT REFUSE_TEMP_BAN_HACKING_INVESTIGATION REFUSE_TEMP_BAN_BUG_INVESTIGATION
						REFUSE_TEMP_BAN_DELETING_CHAR REFUSE_TEMP_BAN_DELETING_SPOUSE_CHAR REFUSE_USER_PHONE_BLOCK
						ACCEPT_LOGIN_USER_PHONE_BLOCK ACCEPT_LOGIN_CHILD REFUSE_IS_NOT_FREEUSER REFUSE_INVALID_ONETIMELIMIT
						REFUSE_CHANGE_PASSWD_FORCE REFUSE_OUTOFDATE_PASSWORD REFUSE_NOT_CHANGE_ACCOUNTID REFUSE_NOT_CHANGE_CHARACTERID
						REFUSE_SSO_AUTH_BLOCK_USER REFUSE_SSO_AUTH_GAME_APPLY REFUSE_SSO_AUTH_INVALID_GAMENUM REFUSE_SSO_AUTH_INVALID_USER
						REFUSE_SSO_AUTH_OTHERS REFUSE_SSO_AUTH_INVALID_AGE REFUSE_SSO_AUTH_INVALID_MACADDRESS REFUSE_SSO_AUTH_BLOCK_ETERNAL
						REFUSE_SSO_AUTH_BLOCK_ACCOUNT_STEAL REFUSE_SSO_AUTH_BLOCK_BUG_INVESTIGATION REFUSE_SSO_NOT_PAY_USER
						REFUSE_SSO_ALREADY_LOGIN_USER REFUSE_SSO_CURRENT_USED_USER REFUSE_SSO_OTHER_1 REFUSE_SSO_DROP_USER
						REFUSE_SSO_NOTHING_USER REFUSE_SSO_OTHER_2 REFUSE_SSO_WRONG_RATETYPE_1 REFUSE_SSO_EXTENSION_PCBANG_TIME
						REFUSE_SSO_WRONG_RATETYPE_2)],
	stat_info => [qw(VAR_SPEED VAR_EXP VAR_JOBEXP VAR_VIRTUE VAR_HONOR VAR_HP VAR_MAXHP VAR_SP VAR_MAXSP VAR_POINT VAR_HAIRCOLOR VAR_CLEVEL VAR_SPPOINT
						VAR_STR VAR_AGI VAR_VIT VAR_INT VAR_DEX VAR_LUK VAR_JOB VAR_MONEY VAR_SEX VAR_MAXEXP VAR_MAXJOBEXP VAR_WEIGHT VAR_MAXWEIGHT VAR_POISON
						VAR_STONE VAR_CURSE VAR_FREEZING VAR_SILENCE VAR_CONFUSION VAR_STANDARD_STR VAR_STANDARD_AGI VAR_STANDARD_VIT VAR_STANDARD_INT
						VAR_STANDARD_DEX VAR_STANDARD_LUK VAR_ATTACKMT VAR_ATTACKEDMT VAR_NV_BASIC VAR_ATTPOWER VAR_REFININGPOWER VAR_MAX_MATTPOWER 
						VAR_MIN_MATTPOWER VAR_ITEMDEFPOWER VAR_PLUSDEFPOWER VAR_MDEFPOWER VAR_PLUSMDEFPOWER VAR_HITSUCCESSVALUE VAR_AVOIDSUCCESSVALUE 
						VAR_PLUSAVOIDSUCCESSVALUE VAR_CRITICALSUCCESSVALUE VAR_ASPD VAR_PLUSASPD VAR_JOBLEVEL VAR_ACCESSORY2 VAR_ACCESSORY3 VAR_HEADPALETTE 
						VAR_BODYPALETTE VAR_PKHONOR VAR_CURXPOS VAR_CURYPOS VAR_CURDIR VAR_CHARACTERID VAR_ACCOUNTID VAR_MAPID VAR_MAPNAME VAR_ACCOUNTNAME 
						VAR_CHARACTERNAME VAR_ITEM_COUNT VAR_ITEM_ITID VAR_ITEM_SLOT1 VAR_ITEM_SLOT2 VAR_ITEM_SLOT3 VAR_ITEM_SLOT4 VAR_HEAD VAR_WEAPON 
						VAR_ACCESSORY VAR_STATE VAR_MOVEREQTIME VAR_GROUPID VAR_ATTPOWERPLUSTIME VAR_ATTPOWERPLUSPERCENT VAR_DEFPOWERPLUSTIME 
						VAR_DEFPOWERPLUSPERCENT VAR_DAMAGENOMOTIONTIME VAR_BODYSTATE VAR_HEALTHSTATE VAR_RESETHEALTHSTATE VAR_CURRENTSTATE VAR_RESETEFFECTIVE 
						VAR_GETEFFECTIVE VAR_EFFECTSTATE VAR_SIGHTABILITYEXPIREDTIME VAR_SIGHTRANGE VAR_SIGHTPLUSATTPOWER VAR_STREFFECTIVETIME 
						VAR_AGIEFFECTIVETIME VAR_VITEFFECTIVETIME VAR_INTEFFECTIVETIME VAR_DEXEFFECTIVETIME VAR_LUKEFFECTIVETIME VAR_STRAMOUNT VAR_AGIAMOUNT 
						VAR_VITAMOUNT VAR_INTAMOUNT VAR_DEXAMOUNT VAR_LUKAMOUNT VAR_MAXHPAMOUNT VAR_MAXSPAMOUNT VAR_MAXHPPERCENT VAR_MAXSPPERCENT 
						VAR_HPACCELERATION VAR_SPACCELERATION VAR_SPEEDAMOUNT VAR_SPEEDDELTA VAR_SPEEDDELTA2 VAR_PLUSATTRANGE VAR_DISCOUNTPERCENT 
						VAR_AVOIDABLESUCCESSPERCENT VAR_STATUSDEFPOWER VAR_PLUSDEFPOWERINACOLYTE VAR_MAGICITEMDEFPOWER VAR_MAGICSTATUSDEFPOWER VAR_CLASS 
						VAR_PLUSATTACKPOWEROFITEM VAR_PLUSDEFPOWEROFITEM VAR_PLUSMDEFPOWEROFITEM VAR_PLUSARROWPOWEROFITEM VAR_PLUSATTREFININGPOWEROFITEM 
						VAR_PLUSDEFREFININGPOWEROFITEM VAR_IDENTIFYNUMBER VAR_ISDAMAGED VAR_ISIDENTIFIED VAR_REFININGLEVEL VAR_WEARSTATE VAR_ISLUCKY 
						VAR_ATTACKPROPERTY VAR_STORMGUSTCNT VAR_MAGICATKPERCENT VAR_MYMOBCOUNT VAR_ISCARTON VAR_GDID VAR_NPCXSIZE VAR_NPCYSIZE VAR_RACE 
						VAR_SCALE VAR_PROPERTY VAR_PLUSATTACKPOWEROFITEM_RHAND VAR_PLUSATTACKPOWEROFITEM_LHAND VAR_PLUSATTREFININGPOWEROFITEM_RHAND 
						VAR_PLUSATTREFININGPOWEROFITEM_LHAND VAR_TOLERACE VAR_ARMORPROPERTY VAR_ISMAGICIMMUNE VAR_ISFALCON VAR_ISRIDING VAR_MODIFIED 
						VAR_FULLNESS VAR_RELATIONSHIP VAR_ACCESSARY VAR_SIZETYPE VAR_SHOES VAR_STATUSATTACKPOWER VAR_BASICAVOIDANCE VAR_BASICHIT 
						VAR_PLUSASPDPERCENT VAR_CPARTY VAR_ISMARRIED VAR_ISGUILD VAR_ISFALCONON VAR_ISPECOON VAR_ISPARTYMASTER VAR_ISGUILDMASTER 
						VAR_BODYSTATENORMAL VAR_HEALTHSTATENORMAL VAR_STUN VAR_SLEEP VAR_UNDEAD VAR_BLIND VAR_BLOODING VAR_BSPOINT VAR_ACPOINT VAR_BSRANK 
						VAR_ACRANK VAR_CHANGESPEED VAR_CHANGESPEEDTIME VAR_MAGICATKPOWER VAR_MER_KILLCOUNT VAR_MER_FAITH VAR_MDEFPERCENT VAR_CRITICAL_DEF 
						VAR_ITEMPOWER VAR_MAGICDAMAGEREDUCE VAR_STATUSMAGICPOWER VAR_PLUSMAGICPOWEROFITEM VAR_ITEMMAGICPOWER VAR_NAME VAR_FSMSTATE 
						VAR_ATTMPOWER VAR_CARTWEIGHT VAR_HP_SELF VAR_SP_SELF VAR_COSTUME_BODY VAR_RESET_COSTUMES)],
	party_invite => [qw(ANSWER_ALREADY_OTHERGROUPM ANSWER_JOIN_REFUSE ANSWER_JOIN_ACCEPT ANSWER_MEMBER_OVERSIZE ANSWER_DUPLICATE 
						ANSWER_JOINMSG_REFUSE ANSWER_UNKNOWN_ERROR ANSWER_UNKNOWN_CHARACTER ANSWER_INVALID_MAPPROPERTY)],
	party_leave => [qw(GROUPMEMBER_DELETE_LEAVE GROUPMEMBER_DELETE_EXPEL)],
	exp_origin => [qw(EXP_FROM_BATTLE EXP_FROM_QUEST)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{actor_type}},
	@{$EXPORT_TAGS{connection}},
	@{$EXPORT_TAGS{stat_info}},
	@{$EXPORT_TAGS{party_invite}},
	@{$EXPORT_TAGS{party_leave}},
	@{$EXPORT_TAGS{exp_origin}},
);

# object_type constants for &actor_display
use constant {
	PC_TYPE => 0x0,
	NPC_TYPE => 0x1,
	ITEM_TYPE => 0x2,
	SKILL_TYPE => 0x3,
	UNKNOWN_TYPE => 0x4,
	NPC_MOB_TYPE => 0x5,
	NPC_EVT_TYPE => 0x6,
	NPC_PET_TYPE => 0x7,
	NPC_HO_TYPE => 0x8,
	NPC_MERSOL_TYPE => 0x9,
	NPC_ELEMENTAL_TYPE => 0xa
};

# connection
use constant {
	REFUSE_INVALID_ID => 0x0,
	REFUSE_INVALID_PASSWD => 0x1,
	REFUSE_ID_EXPIRED => 0x2,
	ACCEPT_ID_PASSWD => 0x3,
	REFUSE_NOT_CONFIRMED => 0x4,
	REFUSE_INVALID_VERSION => 0x5,
	REFUSE_BLOCK_TEMPORARY => 0x6,
	REFUSE_BILLING_NOT_READY => 0x7,
	REFUSE_NONSAKRAY_ID_BLOCKED => 0x8,
	REFUSE_BAN_BY_DBA => 0x9,
	REFUSE_EMAIL_NOT_CONFIRMED => 0xa,
	REFUSE_BAN_BY_GM => 0xb,
	REFUSE_TEMP_BAN_FOR_DBWORK => 0xc,
	REFUSE_SELF_LOCK => 0xd,
	REFUSE_NOT_PERMITTED_GROUP => 0xe,
	REFUSE_WAIT_FOR_SAKRAY_ACTIVE => 0xf,
	REFUSE_NOT_CHANGED_PASSWD => 0x10,
	REFUSE_BLOCK_INVALID => 0x11,
	REFUSE_WARNING => 0x12,
	REFUSE_NOT_OTP_USER_INFO => 0x13,
	REFUSE_OTP_AUTH_FAILED => 0x14,
	REFUSE_SSO_AUTH_FAILED => 0x15,
	REFUSE_NOT_ALLOWED_IP_ON_TESTING => 0x16,
	REFUSE_OVER_BANDWIDTH => 0x17,
	REFUSE_OVER_USERLIMIT => 0x18,
	REFUSE_UNDER_RESTRICTION => 0x19,
	REFUSE_BY_OUTER_SERVER => 0x1a,
	REFUSE_BY_UNIQUESERVER_CONNECTION => 0x1b,
	REFUSE_BY_AUTHSERVER_CONNECTION => 0x1c,
	REFUSE_BY_BILLSERVER_CONNECTION => 0x1d,
	REFUSE_BY_AUTH_WAITING => 0x1e,
	REFUSE_DELETED_ACCOUNT => 0x63,
	REFUSE_ALREADY_CONNECT => 0x64,
	REFUSE_TEMP_BAN_HACKING_INVESTIGATION => 0x65,
	REFUSE_TEMP_BAN_BUG_INVESTIGATION => 0x66,
	REFUSE_TEMP_BAN_DELETING_CHAR => 0x67,
	REFUSE_TEMP_BAN_DELETING_SPOUSE_CHAR => 0x68,
	REFUSE_USER_PHONE_BLOCK => 0x69,
	ACCEPT_LOGIN_USER_PHONE_BLOCK => 0x6a,
	ACCEPT_LOGIN_CHILD => 0x6b,
	REFUSE_IS_NOT_FREEUSER => 0x6c,
	REFUSE_INVALID_ONETIMELIMIT => 0x6d,
	REFUSE_CHANGE_PASSWD_FORCE => 0x6e,
	REFUSE_OUTOFDATE_PASSWORD => 0x6f,
	REFUSE_NOT_CHANGE_ACCOUNTID => 0xf0,
	REFUSE_NOT_CHANGE_CHARACTERID => 0xf1,
	REFUSE_SSO_AUTH_BLOCK_USER => 0x1394,
	REFUSE_SSO_AUTH_GAME_APPLY => 0x1395,
	REFUSE_SSO_AUTH_INVALID_GAMENUM => 0x1396,
	REFUSE_SSO_AUTH_INVALID_USER => 0x1397,
	REFUSE_SSO_AUTH_OTHERS => 0x1398,
	REFUSE_SSO_AUTH_INVALID_AGE => 0x1399,
	REFUSE_SSO_AUTH_INVALID_MACADDRESS => 0x139a,
	REFUSE_SSO_AUTH_BLOCK_ETERNAL => 0x13c6,
	REFUSE_SSO_AUTH_BLOCK_ACCOUNT_STEAL => 0x13c7,
	REFUSE_SSO_AUTH_BLOCK_BUG_INVESTIGATION => 0x13c8,
	REFUSE_SSO_NOT_PAY_USER => 0x13ba,
	REFUSE_SSO_ALREADY_LOGIN_USER => 0x13bb,
	REFUSE_SSO_CURRENT_USED_USER => 0x13bc,
	REFUSE_SSO_OTHER_1 => 0x13bd,
	REFUSE_SSO_DROP_USER => 0x13be,
	REFUSE_SSO_NOTHING_USER => 0x13bf,
	REFUSE_SSO_OTHER_2 => 0x13c0,
	REFUSE_SSO_WRONG_RATETYPE_1 => 0x13c1,
	REFUSE_SSO_EXTENSION_PCBANG_TIME => 0x13c2,
	REFUSE_SSO_WRONG_RATETYPE_2 => 0x13c3,
};

# stat_info
use constant {
	VAR_SPEED => 0x0,
	VAR_EXP => 0x1,
	VAR_JOBEXP => 0x2,
	VAR_VIRTUE => 0x3,
	VAR_HONOR => 0x4,
	VAR_HP => 0x5,
	VAR_MAXHP => 0x6,
	VAR_SP => 0x7,
	VAR_MAXSP => 0x8,
	VAR_POINT => 0x9,
	VAR_HAIRCOLOR => 0xa,
	VAR_CLEVEL => 0xb,
	VAR_SPPOINT => 0xc,
	VAR_STR => 0xd,
	VAR_AGI => 0xe,
	VAR_VIT => 0xf,
	VAR_INT => 0x10,
	VAR_DEX => 0x11,
	VAR_LUK => 0x12,
	VAR_JOB => 0x13,
	VAR_MONEY => 0x14,
	VAR_SEX => 0x15,
	VAR_MAXEXP => 0x16,
	VAR_MAXJOBEXP => 0x17,
	VAR_WEIGHT => 0x18,
	VAR_MAXWEIGHT => 0x19,
	VAR_POISON => 0x1a,
	VAR_STONE => 0x1b,
	VAR_CURSE => 0x1c,
	VAR_FREEZING => 0x1d,
	VAR_SILENCE => 0x1e,
	VAR_CONFUSION => 0x1f,
	VAR_STANDARD_STR => 0x20,
	VAR_STANDARD_AGI => 0x21,
	VAR_STANDARD_VIT => 0x22,
	VAR_STANDARD_INT => 0x23,
	VAR_STANDARD_DEX => 0x24,
	VAR_STANDARD_LUK => 0x25,
	VAR_ATTACKMT => 0x26,
	VAR_ATTACKEDMT => 0x27,
	VAR_NV_BASIC => 0x28,
	VAR_ATTPOWER => 0x29,
	VAR_REFININGPOWER => 0x2a,
	VAR_MAX_MATTPOWER => 0x2b,
	VAR_MIN_MATTPOWER => 0x2c,
	VAR_ITEMDEFPOWER => 0x2d,
	VAR_PLUSDEFPOWER => 0x2e,
	VAR_MDEFPOWER => 0x2f,
	VAR_PLUSMDEFPOWER => 0x30,
	VAR_HITSUCCESSVALUE => 0x31,
	VAR_AVOIDSUCCESSVALUE => 0x32,
	VAR_PLUSAVOIDSUCCESSVALUE => 0x33,
	VAR_CRITICALSUCCESSVALUE => 0x34,
	VAR_ASPD => 0x35,
	VAR_PLUSASPD => 0x36,
	VAR_JOBLEVEL => 0x37,
	VAR_ACCESSORY2 => 0x38,
	VAR_ACCESSORY3 => 0x39,
	VAR_HEADPALETTE => 0x3a,
	VAR_BODYPALETTE => 0x3b,
	VAR_PKHONOR => 0x3c,
	VAR_CURXPOS => 0x3d,
	VAR_CURYPOS => 0x3e,
	VAR_CURDIR => 0x3f,
	VAR_CHARACTERID => 0x40,
	VAR_ACCOUNTID => 0x41,
	VAR_MAPID => 0x42,
	VAR_MAPNAME => 0x43,
	VAR_ACCOUNTNAME => 0x44,
	VAR_CHARACTERNAME => 0x45,
	VAR_ITEM_COUNT => 0x46,
	VAR_ITEM_ITID => 0x47,
	VAR_ITEM_SLOT1 => 0x48,
	VAR_ITEM_SLOT2 => 0x49,
	VAR_ITEM_SLOT3 => 0x4a,
	VAR_ITEM_SLOT4 => 0x4b,
	VAR_HEAD => 0x4c,
	VAR_WEAPON => 0x4d,
	VAR_ACCESSORY => 0x4e,
	VAR_STATE => 0x4f,
	VAR_MOVEREQTIME => 0x50,
	VAR_GROUPID => 0x51,
	VAR_ATTPOWERPLUSTIME => 0x52,
	VAR_ATTPOWERPLUSPERCENT => 0x53,
	VAR_DEFPOWERPLUSTIME => 0x54,
	VAR_DEFPOWERPLUSPERCENT => 0x55,
	VAR_DAMAGENOMOTIONTIME => 0x56,
	VAR_BODYSTATE => 0x57,
	VAR_HEALTHSTATE => 0x58,
	VAR_RESETHEALTHSTATE => 0x59,
	VAR_CURRENTSTATE => 0x5a,
	VAR_RESETEFFECTIVE => 0x5b,
	VAR_GETEFFECTIVE => 0x5c,
	VAR_EFFECTSTATE => 0x5d,
	VAR_SIGHTABILITYEXPIREDTIME => 0x5e,
	VAR_SIGHTRANGE => 0x5f,
	VAR_SIGHTPLUSATTPOWER => 0x60,
	VAR_STREFFECTIVETIME => 0x61,
	VAR_AGIEFFECTIVETIME => 0x62,
	VAR_VITEFFECTIVETIME => 0x63,
	VAR_INTEFFECTIVETIME => 0x64,
	VAR_DEXEFFECTIVETIME => 0x65,
	VAR_LUKEFFECTIVETIME => 0x66,
	VAR_STRAMOUNT => 0x67,
	VAR_AGIAMOUNT => 0x68,
	VAR_VITAMOUNT => 0x69,
	VAR_INTAMOUNT => 0x6a,
	VAR_DEXAMOUNT => 0x6b,
	VAR_LUKAMOUNT => 0x6c,
	VAR_MAXHPAMOUNT => 0x6d,
	VAR_MAXSPAMOUNT => 0x6e,
	VAR_MAXHPPERCENT => 0x6f,
	VAR_MAXSPPERCENT => 0x70,
	VAR_HPACCELERATION => 0x71,
	VAR_SPACCELERATION => 0x72,
	VAR_SPEEDAMOUNT => 0x73,
	VAR_SPEEDDELTA => 0x74,
	VAR_SPEEDDELTA2 => 0x75,
	VAR_PLUSATTRANGE => 0x76,
	VAR_DISCOUNTPERCENT => 0x77,
	VAR_AVOIDABLESUCCESSPERCENT => 0x78,
	VAR_STATUSDEFPOWER => 0x79,
	VAR_PLUSDEFPOWERINACOLYTE => 0x7a,
	VAR_MAGICITEMDEFPOWER => 0x7b,
	VAR_MAGICSTATUSDEFPOWER => 0x7c,
	VAR_CLASS => 0x7d,
	VAR_PLUSATTACKPOWEROFITEM => 0x7e,
	VAR_PLUSDEFPOWEROFITEM => 0x7f,
	VAR_PLUSMDEFPOWEROFITEM => 0x80,
	VAR_PLUSARROWPOWEROFITEM => 0x81,
	VAR_PLUSATTREFININGPOWEROFITEM => 0x82,
	VAR_PLUSDEFREFININGPOWEROFITEM => 0x83,
	VAR_IDENTIFYNUMBER => 0x84,
	VAR_ISDAMAGED => 0x85,
	VAR_ISIDENTIFIED => 0x86,
	VAR_REFININGLEVEL => 0x87,
	VAR_WEARSTATE => 0x88,
	VAR_ISLUCKY => 0x89,
	VAR_ATTACKPROPERTY => 0x8a,
	VAR_STORMGUSTCNT => 0x8b,
	VAR_MAGICATKPERCENT => 0x8c,
	VAR_MYMOBCOUNT => 0x8d,
	VAR_ISCARTON => 0x8e,
	VAR_GDID => 0x8f,
	VAR_NPCXSIZE => 0x90,
	VAR_NPCYSIZE => 0x91,
	VAR_RACE => 0x92,
	VAR_SCALE => 0x93,
	VAR_PROPERTY => 0x94,
	VAR_PLUSATTACKPOWEROFITEM_RHAND => 0x95,
	VAR_PLUSATTACKPOWEROFITEM_LHAND => 0x96,
	VAR_PLUSATTREFININGPOWEROFITEM_RHAND => 0x97,
	VAR_PLUSATTREFININGPOWEROFITEM_LHAND => 0x98,
	VAR_TOLERACE => 0x99,
	VAR_ARMORPROPERTY => 0x9a,
	VAR_ISMAGICIMMUNE => 0x9b,
	VAR_ISFALCON => 0x9c,
	VAR_ISRIDING => 0x9d,
	VAR_MODIFIED => 0x9e,
	VAR_FULLNESS => 0x9f,
	VAR_RELATIONSHIP => 0xa0,
	VAR_ACCESSARY => 0xa1,
	VAR_SIZETYPE => 0xa2,
	VAR_SHOES => 0xa3,
	VAR_STATUSATTACKPOWER => 0xa4,
	VAR_BASICAVOIDANCE => 0xa5,
	VAR_BASICHIT => 0xa6,
	VAR_PLUSASPDPERCENT => 0xa7,
	VAR_CPARTY => 0xa8,
	VAR_ISMARRIED => 0xa9,
	VAR_ISGUILD => 0xaa,
	VAR_ISFALCONON => 0xab,
	VAR_ISPECOON => 0xac,
	VAR_ISPARTYMASTER => 0xad,
	VAR_ISGUILDMASTER => 0xae,
	VAR_BODYSTATENORMAL => 0xaf,
	VAR_HEALTHSTATENORMAL => 0xb0,
	VAR_STUN => 0xb1,
	VAR_SLEEP => 0xb2,
	VAR_UNDEAD => 0xb3,
	VAR_BLIND => 0xb4,
	VAR_BLOODING => 0xb5,
	VAR_BSPOINT => 0xb6,
	VAR_ACPOINT => 0xb7,
	VAR_BSRANK => 0xb8,
	VAR_ACRANK => 0xb9,
	VAR_CHANGESPEED => 0xba,
	VAR_CHANGESPEEDTIME => 0xbb,
	VAR_MAGICATKPOWER => 0xbc,
	VAR_MER_KILLCOUNT => 0xbd,
	VAR_MER_FAITH => 0xbe,
	VAR_MDEFPERCENT => 0xbf,
	VAR_CRITICAL_DEF => 0xc0,
	VAR_ITEMPOWER => 0xc1,
	VAR_MAGICDAMAGEREDUCE => 0xc2,
	VAR_STATUSMAGICPOWER => 0xc3,
	VAR_PLUSMAGICPOWEROFITEM => 0xc4,
	VAR_ITEMMAGICPOWER => 0xc5,
	VAR_NAME => 0xc6,
	VAR_FSMSTATE => 0xc7,
	VAR_ATTMPOWER => 0xc8,
	VAR_CARTWEIGHT => 0xc9,
	VAR_HP_SELF => 0xca,
	VAR_SP_SELF => 0xcb,
	VAR_COSTUME_BODY => 0xcc,
	VAR_RESET_COSTUMES => 0xcd,
};

# party invite result
use constant {
	ANSWER_ALREADY_OTHERGROUPM => 0x0,
	ANSWER_JOIN_REFUSE => 0x1,
	ANSWER_JOIN_ACCEPT => 0x2,
	ANSWER_MEMBER_OVERSIZE => 0x3,
	ANSWER_DUPLICATE => 0x4,
	ANSWER_JOINMSG_REFUSE => 0x5,
	ANSWER_UNKNOWN_ERROR => 0x6,
	ANSWER_UNKNOWN_CHARACTER => 0x7,
	ANSWER_INVALID_MAPPROPERTY => 0x8,
};

# party leave result
use constant {
	GROUPMEMBER_DELETE_LEAVE => 0x0,
	GROUPMEMBER_DELETE_EXPEL => 0x1,
};

# exp origin
use constant {
	EXP_FROM_BATTLE => 0x0,
	EXP_FROM_QUEST => 0x1,
};

# 07F6 (exp) doesn't change any exp information because 00B1 (exp_zeny_info) is always sent with it
# r7643 - copy-pasted to RagexeRE_2009_10_27a.pm
sub exp {
	my ($self, $args) = @_;

	my $max = {VAR_EXP, $char->{exp_max}, VAR_JOBEXP, $char->{exp_job_max}}->{$args->{type}};
	$args->{percent} = $max ? $args->{val} / $max * 100 : 0;

	if ($args->{flag} == EXP_FROM_BATTLE) {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Exp gained: %d\n", @{$args}{qw(type val)}), 'exp2', 2;
		}
	} elsif ($args->{flag} == EXP_FROM_QUEST) {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Quest Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Quest Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Quest Exp gained: %d\n", @{$args}{qw(type val)}), 'exp2', 2;
		}
	} else {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Unknown (flag=%d) Exp gained: %d (%.2f%%)\n", @{$args}{qw(flag val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Unknown (flag=%d) Exp gained: %d (%.2f%%)\n", @{$args}{qw(flag val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Unknown (flag=%d) Exp gained: %d\n", @{$args}{qw(type flag val)}), 'exp2', 2;
		}
	}
}

######################################
### CATEGORY: Class methods
######################################

# Just a wrapper for SUPER::parse.
sub parse {
	my $self = shift;
	my $args = $self->SUPER::parse(@_);

	if ($args && $config{debugPacket_received} == 3 &&
			existsInList($config{'debugPacket_include'}, $args->{switch})) {
		my $packet = $self->{packet_list}{$args->{switch}};
		my ($name, $packString, $varNames) = @{$packet};

		my @vars = ();
		for my $varName (@{$varNames}) {
			message "$varName = $args->{$varName}\n";
		}
	}

	return $args;
}

#######################################
### CATEGORY: Private class methods
#######################################

##
# int Network::Receive::queryLoginPinCode([String message])
# Returns: login PIN code, or undef if cancelled
# Ensures: length(result) in 4..8
#
# Request login PIN code from user.
sub queryLoginPinCode {
	my $message = $_[0] || T("You've never set a login PIN code before.\nPlease enter a new login PIN code:");
	do {
		my $input = $interface->query($message, isPassword => 1,);
		if (!defined($input)) {
			quit();
			return;
		} else {
			if ($input !~ /^\d+$/) {
				$interface->errorDialog(T("The PIN code may only contain digits."));
			} elsif ((length($input) <= 3) || (length($input) >= 9)) {
				$interface->errorDialog(T("The PIN code must be between 4 and 9 characters."));
			} else {
				return $input;
			}
		}
	} while (1);
}

##
# boolean Network::Receive->queryAndSaveLoginPinCode([String message])
# Returns: true on success
#
# Request login PIN code from user and save it in config.
sub queryAndSaveLoginPinCode {
	my ($self, $message) = @_;
	my $pin = queryLoginPinCode($message);
	if (defined $pin) {
		configModify('loginPinCode', $pin, silent => 1);
		return 1;
	} else {
		return 0;
	}
}

sub changeToInGameState {
	if ($net->version() == 1) {
		if ($accountID && UNIVERSAL::isa($char, 'Actor::You')) {
			if ($net->getState() != Network::IN_GAME) {
				$net->setState(Network::IN_GAME);
			}
			return 1;
		} else {
			if ($net->getState() != Network::IN_GAME_BUT_UNINITIALIZED) {
				$net->setState(Network::IN_GAME_BUT_UNINITIALIZED);
				if ($config{verbose} && $messageSender && !$sentWelcomeMessage) {
					$messageSender->injectAdminMessage("Please relogin to enable X-${Settings::NAME}.");
					$sentWelcomeMessage = 1;
				}
			}
			return 0;
		}
	} else {
		return 1;
	}
}

### Packet inner struct handlers

# The block size in the received_characters packet varies from server to server.
# This method may be overrided in other ServerType handlers to return
# the correct block size.
sub received_characters_blockSize {
	if ($masterServer && $masterServer->{charBlockSize}) {
		return $masterServer->{charBlockSize};
	} else {
		return 106;
	}
}

# The length must exactly match charBlockSize, as it's used to construct packets.
sub received_characters_unpackString {
	for ($masterServer && $masterServer->{charBlockSize}) {
		# unknown purpose (0 = disabled, otherwise displays "Add-Ons" sidebar) (from rA)
		# change $hairstyle
		return 'a4 Z8 V Z8 V6 v V2 v4 V v9 Z24 C8 v a16 Z16 C' if $_ == 155;
		return 'a4 V9 v V2 v4 V v9 Z24 C8 v a16 Z16 C' if $_ == 147;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4 x4 C' if $_ == 145;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4 x4' if $_ == 144;
		# change slot feature
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4' if $_ == 140;
		# robe
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4' if $_ == 136;
		# delete date
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V' if $_ == 132;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16' if $_ == 128;
		# bRO (bitfrost update)
		return 'a4 V9 v V2 v14 Z24 C8 v Z12' if $_ == 124;
		return 'a4 V9 v V2 v14 Z24 C6 v2 x4' if $_ == 116; # TODO: (missing 2 last bytes)
		return 'a4 V9 v V2 v14 Z24 C6 v2' if $_ == 112;
		return 'a4 V9 v17 Z24 C6 v2' if $_ == 108;
		return 'a4 V9 v17 Z24 C6 v' if $_ == 106 || !$_;
		die "Unknown charBlockSize: $_";
	}
}

### Parse/reconstruct callbacks and packet handlers

sub parse_account_server_info {
	my ($self, $args) = @_;
	my $server_info;

	if ($args->{switch} eq '0069') {  # DEFAULT PACKET
		$server_info = {
			len => 32,
			types => 'a4 v Z20 v2 x2',
			keys => [qw(ip port name users display)],
		};

	} elsif ($args->{switch} eq '0AC4') { # kRO Zero 2017, kRO ST 201703+
		$server_info = {
			len => 160,
			types => 'a4 v Z20 v3 a128',
			keys => [qw(ip port name users state property unknown)],
		};
		
	} elsif ($args->{switch} eq '0AC9') { # cRO 2017
		$server_info = {
			len => 154,
			types => 'a20 V a2 a126',
			keys => [qw(name users unknown ip_port)],
		};
		
	} else { # this can't happen
		return;
	}

	@{$args->{servers}} = map {
		my %server;
		@server{@{$server_info->{keys}}} = unpack($server_info->{types}, $_);
		if ($masterServer && $masterServer->{private}) {
			$server{ip} = $masterServer->{ip};
		} elsif ($args->{switch} eq '0AC9') {
			@server{qw(ip port)} = split (/\:/, $server{ip_port});
			$server{ip} =~ s/^\s+|\s+$//g;
			$server{port} =~ tr/0-9//cd;
		} else {
			$server{ip} = inet_ntoa($server{ip});
		}
		$server{name} = bytesToString($server{name});
		\%server
	} unpack '(a'.$server_info->{len}.')*', $args->{serverInfo};

	if (length $args->{lastLoginIP} == 4 && $args->{lastLoginIP} ne "\0"x4) {
		$args->{lastLoginIP} = inet_ntoa($args->{lastLoginIP});
	} else {
		delete $args->{lastLoginIP};
	}
}

sub reconstruct_account_server_info {
	my ($self, $args) = @_;
	$args->{lastLoginIP} = inet_aton($args->{lastLoginIP});

	if($args->{'switch'} eq "0AC4") {
		$args->{serverInfo} = pack '(a160)*', map { pack(
			'a4 v Z20 v3 a128',
			inet_aton($_->{ip}),
			$_->{port},
			stringToBytes($_->{name}),
			@{$_}{qw(users state property unknown)},
		) } @{$args->{servers}};
	} elsif($args->{'switch'} eq "0AC9") {
		$args->{serverInfo} = pack '(a154)*', map { pack(
			'a20 V a2 a126',
			@{$_}{qw(name users unknown ip_port)},
		) } @{$args->{servers}};
	} else {
		$args->{serverInfo} = pack '(a32)*', map { pack(
			'a4 v Z20 v2 x2',
			inet_aton($_->{ip}),
			$_->{port},
			stringToBytes($_->{name}),
			@{$_}{qw(users display)},
		) } @{$args->{servers}};
	}
}

sub account_server_info {
	my ($self, $args) = @_;

	$net->setState(2);
	undef $conState_tries;
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	# Account sex should only be 0 (female) or 1 (male)
	# inRO gives female as 2 but expects 0 back
	# do modulus of 2 here to fix?
	# FIXME: we should check exactly what operation the client does to the number given
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	# any servers with lastLoginIP lastLoginTime?
	# message TF("Last login: %s from %s\n", @{$args}{qw(lastLoginTime lastLoginIP)}) if ...;

	message 
		center(T(" Account Info "), 34, '-') ."\n" .
		swrite(
		T("Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"            \@<<<<<<<<< \@<<<<<<<<<<\n"),
		[unpack('V',$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack('V',$sessionID), getHex($sessionID),
		unpack('V',$sessionID2), getHex($sessionID2)]) .
		('-'x34) . "\n", 'connection';

	@servers = @{$args->{servers}};

	my $msg = center(T(" Servers "), 53, '-') ."\n" .
			T("#   Name                  Users  IP              Port\n");
	for (my $num = 0; $num < @servers; $num++) {
		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]);
	}
	$msg .= ('-'x53) . "\n";
	message $msg, "connection";

	if ($net->version != 1) {
		message T("Closing connection to Account Server\n"), 'connection';
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@serverList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
			}

		} elsif ($masterServer->{charServer_ip}) {
			message TF("Forcing connect to char server %s: %s\n", $masterServer->{charServer_ip}, $masterServer->{charServer_port}), 'connection';
		}
	}

	# FIXME better support for multiple received_characters packets
	undef @chars;
	if ($config{'XKore'} eq '1') {
		$incomingMessages->nextMessageMightBeAccountID();
	}
}

sub connection_refused {
	my ($self, $args) = @_;

	error TF("The server has denied your connection (error: %d).\n", $args->{error}), 'connection';
}

our %stat_info_handlers = (
	VAR_SPEED, sub { $_[0]{walk_speed} = $_[1] / 1000 },
	VAR_EXP, sub {
		my ($actor, $value) = @_;

		$actor->{exp_last} = $actor->{exp};
		$actor->{exp} = $value;

		return unless $actor->isa('Actor::You');
=pod
		unless ($bExpSwitch) {
			$bExpSwitch = 1;
		} else {
			if ($actor->{exp_last} > $actor->{exp}) {
				$monsterBaseExp = 0;
			} else {
				$monsterBaseExp = $actor->{exp} - $actor->{exp_last};
			}
			$totalBaseExp += $monsterBaseExp;
			if ($bExpSwitch == 1) {
				$totalBaseExp += $monsterBaseExp;
				$bExpSwitch = 2;
			}
		}
=cut

		if ($actor->{lastBaseLvl} eq $actor->{lv}) {
			$monsterBaseExp = $actor->{exp} - $actor->{exp_last};
		} else {
			$monsterBaseExp = $actor->{exp_max_last2} - $actor->{exp_last} + $actor->{exp};
			$actor->{lastBaseLvl} = $actor->{lv};
			$actor->{exp_max_last2} = $actor->{exp_max};
		}

		if ($monsterBaseExp > 0) {
			$totalBaseExp += $monsterBaseExp;
		}

		# no VAR_JOBEXP next - no message?
	},
	VAR_JOBEXP, sub {
		my ($actor, $value) = @_;

		$actor->{exp_job_last} = $actor->{exp_job};
		$actor->{exp_job} = $value;

		# TODO: message for all actors
		return unless $actor->isa('Actor::You');
		# TODO: exp report (statistics) - no globals, move to plugin
=pod
		if ($jExpSwitch == 0) {
			$jExpSwitch = 1;
		} else {
			if ($char->{exp_job_last} > $char->{exp_job}) {
				$monsterJobExp = 0;
			} else {
				$monsterJobExp = $char->{exp_job} - $char->{exp_job_last};
			}
			$totalJobExp += $monsterJobExp;
			if ($jExpSwitch == 1) {
				$totalJobExp += $monsterJobExp;
				$jExpSwitch = 2;
			}
		}
=cut

		if ($actor->{lastJobLvl} eq $actor->{lv_job}) {
			$monsterJobExp = $actor->{exp_job} - $actor->{exp_job_last};
		} else {
			$monsterJobExp = $actor->{exp_job_max_last2} - $actor->{exp_job_last} + $actor->{exp_job};
			$actor->{lastJobLvl} = $actor->{lv_job};
			$actor->{exp_job_max_last2} = $actor->{exp_job_max};
		}

		if ($monsterJobExp > 0) {
			$totalJobExp += $monsterJobExp;
		}

		my $basePercent = $char->{exp_max} ?
			($monsterBaseExp / $char->{exp_max} * 100) :
			0;
		my $jobPercent = $char->{exp_job_max} ?
			($monsterJobExp / $char->{exp_job_max} * 100) :
			0;
		message TF("%s have gained %d/%d (%.2f%%/%.2f%%) Exp\n", $char, $monsterBaseExp, $monsterJobExp, $basePercent, $jobPercent), "exp";
		Plugins::callHook('exp_gained');
	},
	#VAR_VIRTUE
	VAR_HONOR, sub {
		my ($actor, $value) = @_;

		if ($value > 0) {
			my $duration = 0xffffffff - $value + 1;
			$actor->{mute_period} = $duration * 60;
			$actor->{muted} = time;
			message sprintf(
				$actor->verb(T("%s have been muted for %d minutes\n"), T("%s has been muted for %d minutes\n")),
				$actor, $duration
			), "parseMsg_statuslook", $actor->isa('Actor::You') ? 1 : 2;
		} else {
			delete $actor->{muted};
			delete $actor->{mute_period};
			message sprintf(
				$actor->verb(T("%s are no longer muted."), T("%s is no longer muted.")), $actor
			), "parseMsg_statuslook", $actor->isa('Actor::You') ? 1 : 2;
		}

		return unless $actor->isa('Actor::You');

		if ($config{dcOnMute} && $actor->{muted}) {
			error TF("Auto disconnecting, %s have been muted for %s minutes!\n", $actor, $actor->{mute_period}/60);
			chatLog("k", TF("*** %s have been muted for %d minutes, auto disconnect! ***\n", $actor, $actor->{mute_period}/60));
			$messageSender->sendQuit();
			quit();
		}
	},
	VAR_HP, sub {
		$_[0]{hp} = $_[1];
		$_[0]{hpPercent} = $_[0]{hp_max} ? 100 * $_[0]{hp} / $_[0]{hp_max} : undef;
	},
	VAR_MAXHP, sub {
		$_[0]{hp_max} = $_[1];
		$_[0]{hpPercent} = $_[0]{hp_max} ? 100 * $_[0]{hp} / $_[0]{hp_max} : undef;
	},
	VAR_SP, sub {
		$_[0]{sp} = $_[1];
		$_[0]{spPercent} = $_[0]{sp_max} ? 100 * $_[0]{sp} / $_[0]{sp_max} : undef;
	},
	VAR_MAXSP, sub {
		$_[0]{sp_max} = $_[1];
		$_[0]{spPercent} = $_[0]{sp_max} ? 100 * $_[0]{sp} / $_[0]{sp_max} : undef;
	},
	VAR_POINT, sub { $_[0]{points_free} = $_[1] },
	#VAR_HAIRCOLOR
	VAR_CLEVEL, sub {
		my ($actor, $value) = @_;

		$actor->{lv} = $value;

		message sprintf($actor->verb(T("%s are now level %d\n"), T("%s is now level %d\n")), $actor, $value), "success", $actor->isa('Actor::You') ? 1 : 2;

		return unless $actor->isa('Actor::You');

		Plugins::callHook('base_level_changed', {
			level	=> $actor->{lv}
		});

		if ($config{dcOnLevel} && $actor->{lv} >= $config{dcOnLevel}) {
			message TF("Disconnecting on level %s!\n", $config{dcOnLevel});
			chatLog("k", TF("Disconnecting on level %s!\n", $config{dcOnLevel}));
			quit();
		}
	},
	VAR_SPPOINT, sub { $_[0]{points_skill} = $_[1] },
	#VAR_STR
	#VAR_AGI
	#VAR_VIT
	#VAR_INT
	#VAR_DEX
	#VAR_LUK
	#VAR_JOB
	VAR_MONEY, sub {
		my ($actor, $value) = @_;

		my $change = $value - $actor->{zeny};
		$actor->{zeny} = $value;

		message sprintf(
			$change > 0
			? $actor->verb(T("%s gained %s zeny.\n"), T("%s gained %s zeny.\n"))
			: $actor->verb(T("%s lost %s zeny.\n"), T("%s lost %s zeny.\n")),
			$actor, formatNumber(abs $change)
		), 'info', $actor->isa('Actor::You') ? 1 : 2 if $change;

		return unless $actor->isa('Actor::You');

		Plugins::callHook('zeny_change', {
			zeny	=> $actor->{zeny},
			change	=> $change,
		});


		if ($config{dcOnZeny} && $actor->{zeny} <= $config{dcOnZeny}) {
			$messageSender->sendQuit();
			error (TF("Auto disconnecting due to zeny lower than %s!\n", $config{dcOnZeny}));
			chatLog("k", T("*** You have no money, auto disconnect! ***\n"));
			quit();
		}
	},
	#VAR_SEX
	VAR_MAXEXP, sub {
		$_[0]{exp_max_last} = $_[0]{exp_max};
		$_[0]{exp_max_last2} = $_[0]{exp_max} if !$_[0]{exp_max_last2};
		$_[0]{exp_max} = $_[1];

		if (!$net->clientAlive() && $initSync && $masterServer->{serverType} == 2) {
			$messageSender->sendSync(1);
			$initSync = 0;
		}
	},
	VAR_MAXJOBEXP, sub {
		$_[0]{exp_job_max_last} = $_[0]{exp_job_max};
		$_[0]{exp_job_max_last2} = $_[0]{exp_job_max} if !$_[0]{exp_job_max_last2};
		$_[0]{exp_job_max} = $_[1];
		#message TF("BaseExp: %s | JobExp: %s\n", $monsterBaseExp, $monsterJobExp), "info", 2 if ($monsterBaseExp);
	},
	VAR_WEIGHT, sub { $_[0]{weight} = $_[1] / 10 },
	VAR_MAXWEIGHT, sub { $_[0]{weight_max} = int($_[1] / 10) },
	#VAR_POISON
	#VAR_STONE
	#VAR_CURSE
	#VAR_FREEZING
	#VAR_SILENCE
	#VAR_CONFUSION
	VAR_STANDARD_STR, sub { $_[0]{points_str} = $_[1] },
	VAR_STANDARD_AGI, sub { $_[0]{points_agi} = $_[1] },
	VAR_STANDARD_VIT, sub { $_[0]{points_vit} = $_[1] },
	VAR_STANDARD_INT, sub { $_[0]{points_int} = $_[1] },
	VAR_STANDARD_DEX, sub { $_[0]{points_dex} = $_[1] },
	VAR_STANDARD_LUK, sub { $_[0]{points_luk} = $_[1] },
	#VAR_ATTACKMT
	#VAR_ATTACKEDMT
	#VAR_NV_BASIC
	VAR_ATTPOWER, sub { $_[0]{attack} = $_[1] },
	VAR_REFININGPOWER, sub { $_[0]{attack_bonus} = $_[1] },
	VAR_MAX_MATTPOWER, sub { $_[0]{attack_magic_max} = $_[1] },
	VAR_MIN_MATTPOWER, sub { $_[0]{attack_magic_min} = $_[1] },
	VAR_ITEMDEFPOWER, sub { $_[0]{def} = $_[1] },
	VAR_PLUSDEFPOWER, sub { $_[0]{def_bonus} = $_[1] },
	VAR_MDEFPOWER, sub { $_[0]{def_magic} = $_[1] },
	VAR_PLUSMDEFPOWER, sub { $_[0]{def_magic_bonus} = $_[1] },
	VAR_HITSUCCESSVALUE, sub { $_[0]{hit} = $_[1] },
	VAR_AVOIDSUCCESSVALUE, sub { $_[0]{flee} = $_[1] },
	VAR_PLUSAVOIDSUCCESSVALUE, sub { $_[0]{flee_bonus} = $_[1] },
	VAR_CRITICALSUCCESSVALUE, sub { $_[0]{critical} = $_[1] },
	VAR_ASPD, sub {
		$_[0]{attack_delay} = $_[1] >= 10 ? $_[1] : 10; # at least for mercenary
		$_[0]{attack_speed} = 200 - $_[0]{attack_delay} / 10;
	},
	#VAR_PLUSASPD
	VAR_JOBLEVEL, sub {
		my ($actor, $value) = @_;

		$actor->{lv_job} = $value;
		message sprintf($actor->verb("%s are now job level %d\n", "%s is now job level %d\n"), $actor, $actor->{lv_job}), "success", $actor->isa('Actor::You') ? 1 : 2;

		return unless $actor->isa('Actor::You');
		
		Plugins::callHook('job_level_changed', {
			level	=> $actor->{lv_job}
		});

		if ($config{dcOnJobLevel} && $actor->{lv_job} >= $config{dcOnJobLevel}) {
			message TF("Disconnecting on job level %d!\n", $config{dcOnJobLevel});
			chatLog("k", TF("Disconnecting on job level %d!\n", $config{dcOnJobLevel}));
			quit();
		}
	},
	#...
	VAR_MER_KILLCOUNT, sub { $_[0]{kills} = $_[1] },
	VAR_MER_FAITH, sub { $_[0]{faith} = $_[1] },
	#...
);

sub stat_info {
	my ($self, $args) = @_;

	return unless changeToInGameState;

	my $actor = {
		'00B0' => $char,
		'00B1' => $char,
		'00BE' => $char,
		'0141' => $char,
		'01AB' => exists $args->{ID} && Actor::get($args->{ID}),
		'02A2' => $char->{mercenary},
		'07DB' => $char->{homunculus},
		'0ACB' => $char,
	}->{$args->{switch}};

	if($args->{switch} eq "081E") {
		if(!$char->{elemental}) {
			$char->{elemental} = new Actor::Elemental;
		}
		$actor = $char->{elemental}; # Sorcerer's Spirit
	}

	unless ($actor) {
		warning sprintf "Actor is unknown or not ready for stat information (switch %s, type %d, val %d)\n", @{$args}{qw(switch type val)};
		return;
	}

	if (exists $stat_info_handlers{$args->{type}}) {
		# TODO: introduce Actor->something() to determine per-actor configurable verbosity level? (not only here)
		debug "Stat: $args->{type} => $args->{val}\n", "parseMsg",  $_[0]->isa('Actor::You') ? 1 : 2;
		$stat_info_handlers{$args->{type}}($actor, $args->{val});
	} else {
		warning sprintf "Unknown stat (%d => %d) received for %s\n", @{$args}{qw(type val)}, $actor;
	}

	if (!$char->{walk_speed}) {
		$char->{walk_speed} = 0.15; # This is the default speed, since xkore requires this and eA (And aegis?) do not send this if its default speed
	}
}


# TODO: merge with stat_info
sub stats_added {
	my ($self, $args) = @_;

	if ($args->{val} == 207) { # client really checks this and not the result field?
		error T("Not enough stat points to add\n");
	} else {
		if ($args->{type} == VAR_STR) {
			$char->{str} = $args->{val};
			debug "Strength: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_AGI) {
			$char->{agi} = $args->{val};
			debug "Agility: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_VIT) {
			$char->{vit} = $args->{val};
			debug "Vitality: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_INT) {
			$char->{int} = $args->{val};
			debug "Intelligence: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_DEX) {
			$char->{dex} = $args->{val};
			debug "Dexterity: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_LUK) {
			$char->{luk} = $args->{val};
			debug "Luck: $args->{val}\n", "parseMsg";

		} else {
			debug "Something: $args->{val}\n", "parseMsg";
		}
	}
	Plugins::callHook('packet_charStats', {
		type	=> $args->{type},
		val	=> $args->{val},
	});
}

sub stats_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	$char->{points_free} = $args->{points_free};
	$char->{str} = $args->{str};
	$char->{points_str} = $args->{points_str};
	$char->{agi} = $args->{agi};
	$char->{points_agi} = $args->{points_agi};
	$char->{vit} = $args->{vit};
	$char->{points_vit} = $args->{points_vit};
	$char->{int} = $args->{int};
	$char->{points_int} = $args->{points_int};
	$char->{dex} = $args->{dex};
	$char->{points_dex} = $args->{points_dex};
	$char->{luk} = $args->{luk};
	$char->{points_luk} = $args->{points_luk};
	$char->{attack} = $args->{attack};
	$char->{attack_bonus} = $args->{attack_bonus};
	$char->{attack_magic_min} = $args->{attack_magic_min};
	$char->{attack_magic_max} = $args->{attack_magic_max};
	$char->{def} = $args->{def};
	$char->{def_bonus} = $args->{def_bonus};
	$char->{def_magic} = $args->{def_magic};
	$char->{def_magic_bonus} = $args->{def_magic_bonus};
	$char->{hit} = $args->{hit};
	$char->{flee} = $args->{flee};
	$char->{flee_bonus} = $args->{flee_bonus};
	$char->{critical} = $args->{critical};
	debug	"Strength: $char->{str} #$char->{points_str}\n"
		."Agility: $char->{agi} #$char->{points_agi}\n"
		."Vitality: $char->{vit} #$char->{points_vit}\n"
		."Intelligence: $char->{int} #$char->{points_int}\n"
		."Dexterity: $char->{dex} #$char->{points_dex}\n"
		."Luck: $char->{luk} #$char->{points_luk}\n"
		."Attack: $char->{attack}\n"
		."Attack Bonus: $char->{attack_bonus}\n"
		."Magic Attack Min: $char->{attack_magic_min}\n"
		."Magic Attack Max: $char->{attack_magic_max}\n"
		."Defense: $char->{def}\n"
		."Defense Bonus: $char->{def_bonus}\n"
		."Magic Defense: $char->{def_magic}\n"
		."Magic Defense Bonus: $char->{def_magic_bonus}\n"
		."Hit: $char->{hit}\n"
		."Flee: $char->{flee}\n"
		."Flee Bonus: $char->{flee_bonus}\n"
		."Critical: $char->{critical}\n"
		."Status Points: $char->{points_free}\n", "parseMsg";
}

sub stat_info2 {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $val, $val2) = @{$args}{qw(type val val2)};
	if ($type == VAR_STR) {
		$char->{str} = $val;
		$char->{str_bonus} = $val2;
		debug "Strength: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_AGI) {
		$char->{agi} = $val;
		$char->{agi_bonus} = $val2;
		debug "Agility: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_VIT) {
		$char->{vit} = $val;
		$char->{vit_bonus} = $val2;
		debug "Vitality: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_INT) {
		$char->{int} = $val;
		$char->{int_bonus} = $val2;
		debug "Intelligence: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_DEX) {
		$char->{dex} = $val;
		$char->{dex_bonus} = $val2;
		debug "Dexterity: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_LUK) {
		$char->{luk} = $val;
		$char->{luk_bonus} = $val2;
		debug "Luck: $val + $val2\n", "parseMsg";
	}
}

*actor_exists = *actor_display_compatibility;
*actor_connected = *actor_display_compatibility;
*actor_moved = *actor_display_compatibility;
*actor_spawned = *actor_display_compatibility;
sub actor_display_compatibility {
	my ($self, $args) = @_;
	# compatibility; TODO do it in PacketParser->parse?
	Plugins::callHook('packet_pre/actor_display', $args);
	&actor_display unless $args->{return};
	Plugins::callHook('packet/actor_display', $args);
}

# This function is a merge of actor_exists, actor_connected, actor_moved, etc...
sub actor_display {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($actor, $mustAdd);


	#### Initialize ####

	my $nameID = unpack("V", $args->{ID});

	if ($args->{switch} eq "0086") {
		# Message 0086 contains less information about the actor than other similar
		# messages. So we use the existing actor information.
		my $coordsArg = $args->{coords};
		my $tickArg = $args->{tick};
		$args = Actor::get($args->{ID})->deepCopy();
		# Here we overwrite the $args data with the 0086 packet data.
		$args->{switch} = "0086";
		$args->{coords} = $coordsArg;
		$args->{tick} = $tickArg; # lol tickcount what do we do with that? debug "tick: " . $tickArg/1000/3600/24 . "\n";
	}

	my (%coordsFrom, %coordsTo);
	if (length $args->{coords} == 6) {
		# Actor Moved
		makeCoordsFromTo(\%coordsFrom, \%coordsTo, $args->{coords}); # body dir will be calculated using the vector
	} else {
		# Actor Spawned/Exists
		makeCoordsDir(\%coordsTo, $args->{coords}, \$args->{body_dir});
		%coordsFrom = %coordsTo;
	}

	# Remove actors that are located outside the map
	# This may be caused by:
	#  - server sending us false actors
	#  - actor packets not being parsed correctly
	if (defined $field && ($field->isOffMap($coordsFrom{x}, $coordsFrom{y}) || $field->isOffMap($coordsTo{x}, $coordsTo{y}))) {
		warning TF("Removed actor with off map coordinates: (%d,%d)->(%d,%d), field max: (%d,%d)\n",$coordsFrom{x},$coordsFrom{y},$coordsTo{x},$coordsTo{y},$field->width(),$field->height());
		return;
	}

	# Remove actors with a distance greater than removeActorWithDistance. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond removeActorWithDistance.
	if ($config{removeActorWithDistance}) {
		if ((my $block_dist = blockDistance($char->{pos_to}, \%coordsTo)) > ($config{removeActorWithDistance})) {
			my $nameIdTmp = unpack("V", $args->{ID});
			debug "Removed out of sight actor $nameIdTmp at ($coordsTo{x}, $coordsTo{y}) (distance: $block_dist)\n";
			return;
		}
	}
=pod
	# Zealotus bug
	if ($args->{type} == 1200) {
		open DUMP, ">> test_Zealotus.txt";
		print DUMP "Zealotus: " . $nameID . "\n";
		print DUMP Dumper($args);
		close DUMP;
	}
=cut

	#### Step 0: determine object type ####
	my $object_class;
	if (defined $args->{object_type}) {
		if ($args->{type} == 45) { # portals use the same object_type as NPCs
			$object_class = 'Actor::Portal';
		} else {
			$object_class = {
				PC_TYPE, 'Actor::Player',
				# NPC_TYPE? # not encountered, NPCs are NPC_EVT_TYPE
				# SKILL_TYPE? # not encountered
				# UNKNOWN_TYPE? # not encountered
				NPC_MOB_TYPE, 'Actor::Monster',
				NPC_EVT_TYPE, 'Actor::NPC', # both NPCs and portals
				NPC_PET_TYPE, 'Actor::Pet',
				NPC_HO_TYPE, 'Actor::Slave',
				NPC_MERSOL_TYPE, 'Actor::Slave',
				# NPC_ELEMENTAL_TYPE, 'Actor::Elemental', # Sorcerer's Spirit
			}->{$args->{object_type}};
		}

	}

	unless (defined $object_class) {
		if ($jobs_lut{$args->{type}}) {
			unless ($args->{type} > 6000) {
				$object_class = 'Actor::Player';
			} else {
				$object_class = 'Actor::Slave';
			}
		} elsif ($args->{type} == 45) {
			$object_class = 'Actor::Portal';

		} elsif ($args->{type} >= 1000) {
			if ($args->{hair_style} == 0x64) {
				$object_class = 'Actor::Pet';
			} else {
				$object_class = 'Actor::Monster';
			}
		} else {   # ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
			$object_class = 'Actor::NPC';
		}
	}

	#### Step 1: create the actor object ####

	if ($object_class eq 'Actor::Player') {
		# Actor is a player
		$actor = $playersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Player();
			$actor->{appear_time} = time;
			# New actor_display packets include the player's name
			if ($args->{switch} eq "0086") {
				$actor->{name} = $args->{name};
			} else {
				$actor->{name} = bytesToString($args->{name}) if exists $args->{name};
			}
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Slave') {
		# Actor is a homunculus or a mercenary
		$actor = $slavesList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = ($char->{slaves} && $char->{slaves}{$args->{ID}})
			? $char->{slaves}{$args->{ID}} : new Actor::Slave ($args->{type});

			$actor->{appear_time} = time;
			$actor->{name_given} = bytesToString($args->{name}) if exists $args->{name};
			$actor->{jobId} = $args->{type} if exists $args->{type};
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Portal') {
		# Actor is a portal
		$actor = $portalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Portal();
			$actor->{appear_time} = time;
			my $exists = portalExists($field->baseName, \%coordsTo);
			$actor->{source}{map} = $field->baseName;
			if ($exists ne "") {
				$actor->setName("$portals_lut{$exists}{source}{map} -> " . getPortalDestName($exists));
			}
			$mustAdd = 1;

			# Strangely enough, portals (like all other actors) have names, too.
			# We _could_ send a "actor_info_request" packet to find the names of each portal,
			# however I see no gain from this. (And it might even provide another way of private
			# servers to auto-ban bots.)
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Pet') {
		# Actor is a pet
		$actor = $petsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Pet();
			$actor->{appear_time} = time;
			$actor->{name} = $args->{name};
#			if ($monsters_lut{$args->{type}}) {
#				$actor->setName($monsters_lut{$args->{type}});
#			}
			$actor->{name_given} = exists $args->{name} ? bytesToString($args->{name}) : T("Unknown");
			$mustAdd = 1;

			# Previously identified monsters could suddenly be identified as pets.
			if ($monstersList->getByID($args->{ID})) {
				$monstersList->removeByID($args->{ID});
			}

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};

		}
	} elsif ($object_class eq 'Actor::Monster') {
		$actor = $monstersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Monster();
			$actor->{appear_time} = time;
			if ($monsters_lut{$args->{type}}) {
				$actor->setName($monsters_lut{$args->{type}});
			}
			#$actor->{name_given} = exists $args->{name} ? bytesToString($args->{name}) : "Unknown";
			$actor->{name_given} = "Unknown";
			$actor->{binType} = $args->{type};
			$mustAdd = 1;

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};
		}
	} elsif ($object_class eq 'Actor::NPC') {
		# Actor is an NPC
		$actor = $npcsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::NPC();
			$actor->{appear_time} = time;
			$actor->{name} = bytesToString($args->{name}) if exists $args->{name};
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Elemental') {
		# Actor is a Elemental
		$actor = $elementalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Elemental();
			$actor->{appear_time} = time;
			$mustAdd = 1;
		}
		$actor->{name} = $jobs_lut{$args->{type}};
	}

	#### Step 2: update actor information ####
	$actor->{ID} = $args->{ID};
	$actor->{charID} = $args->{charID} if $args->{charID} && $args->{charID} ne "\0\0\0\0";
	$actor->{jobID} = $args->{type};
	$actor->{type} = $args->{type};
	$actor->{lv} = $args->{lv};
	$actor->{pos} = {%coordsFrom};
	$actor->{pos_to} = {%coordsTo};
	$actor->{walk_speed} = $args->{walk_speed} / 1000 if (exists $args->{walk_speed} && $args->{switch} ne "0086");
	$actor->{time_move} = time;
	$actor->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $actor->{walk_speed};
	$actor->{len} = $args->{len} if $args->{len};
	# 0086 would need that?
	$actor->{object_type} = $args->{object_type} if (defined $args->{object_type});

	if (UNIVERSAL::isa($actor, "Actor::Player")) {
		# None of this stuff should matter if the actor isn't a player... => does matter for a guildflag npc!

		# Interesting note about emblemID. If it is 0 (or none), the Ragnarok
		# client will display "Send (Player) a guild invitation" (assuming one has
		# invitation priveledges), regardless of whether or not guildID is set.
		# I bet that this is yet another brilliant "feature" by GRAVITY's good programmers.
		$actor->{emblemID} = $args->{emblemID} if (exists $args->{emblemID});
		$actor->{guildID} = $args->{guildID} if (exists $args->{guildID});

		if (exists $args->{lowhead}) {
			$actor->{headgear}{low} = $args->{lowhead};
			$actor->{headgear}{mid} = $args->{midhead};
			$actor->{headgear}{top} = $args->{tophead};
			$actor->{weapon} = $args->{weapon};
			$actor->{shield} = $args->{shield};
		}

		$actor->{sex} = $args->{sex};

		if ($args->{act} == 1) {
			$actor->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$actor->{sitting} = 1;
		}

		# Monsters don't have hair colors or heads to look around...
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

	} elsif (UNIVERSAL::isa($actor, "Actor::NPC") && $args->{type} == 722) { # guild flag has emblem
		# odd fact: "this data can also be found in a strange place:
		# (shield OR lowhead) + midhead = emblemID		(either shield or lowhead depending on the packet)
		# tophead = guildID
		$actor->{emblemID} = $args->{emblemID};
		$actor->{guildID} = $args->{guildID};
	}

	# But hair_style is used for pets, and their bodies can look different ways...
	$actor->{hair_style} = $args->{hair_style} if (exists $args->{hair_style});
	$actor->{look}{body} = $args->{body_dir} if (exists $args->{body_dir});
	$actor->{look}{head} = $args->{head_dir} if (exists $args->{head_dir});

	# When stance is non-zero, character is bobbing as if they had just got hit,
	# but the cursor also turns to a sword when they are mouse-overed.
	#$actor->{stance} = $args->{stance} if (exists $args->{stance});

	# Visual effects are a set of flags (some of the packets don't have this argument)
	$actor->{opt3} = $args->{opt3} if (exists $args->{opt3}); # stackable

	# Known visual effects:
	# 0x0001 = Yellow tint (eg, a quicken skill)
	# 0x0002 = Red tint (eg, power-thrust)
	# 0x0004 = Gray tint (eg, energy coat)
	# 0x0008 = Slow lightning (eg, mental strength)
	# 0x0010 = Fast lightning (eg, MVP fury)
	# 0x0020 = Black non-moving statue (eg, stone curse)
	# 0x0040 = Translucent weapon
	# 0x0080 = Translucent red sprite (eg, marionette control?)
	# 0x0100 = Spaztastic weapon image (eg, mystical amplification)
	# 0x0200 = Gigantic glowy sphere-thing
	# 0x0400 = Translucent pink sprite (eg, marionette control?)
	# 0x0800 = Glowy sprite outline (eg, assumptio)
	# 0x1000 = Bright red sprite, slowly moving red lightning (eg, MVP fury?)
	# 0x2000 = Vortex-type effect

	# Note that these are flags, and you can mix and match them
	# Example: 0x000C (0x0008 & 0x0004) = gray tint with slow lightning

=pod
typedef enum <unnamed-tag> {
  SHOW_EFST_NORMAL =  0x0,
  SHOW_EFST_QUICKEN =  0x1,
  SHOW_EFST_OVERTHRUST =  0x2,
  SHOW_EFST_ENERGYCOAT =  0x4,
  SHOW_EFST_EXPLOSIONSPIRITS =  0x8,
  SHOW_EFST_STEELBODY =  0x10,
  SHOW_EFST_BLADESTOP =  0x20,
  SHOW_EFST_AURABLADE =  0x40,
  SHOW_EFST_REDBODY =  0x80,
  SHOW_EFST_LIGHTBLADE =  0x100,
  SHOW_EFST_MOON =  0x200,
  SHOW_EFST_PINKBODY =  0x400,
  SHOW_EFST_ASSUMPTIO =  0x800,
  SHOW_EFST_SUN_WARM =  0x1000,
  SHOW_EFST_REFLECT =  0x2000,
  SHOW_EFST_BUNSIN =  0x4000,
  SHOW_EFST_SOULLINK =  0x8000,
  SHOW_EFST_UNDEAD =  0x10000,
  SHOW_EFST_CONTRACT =  0x20000,
} <unnamed-tag>;
=cut

	# Save these parameters ...
	$actor->{opt1} = $args->{opt1}; # nonstackable
	$actor->{opt2} = $args->{opt2}; # stackable
	$actor->{option} = $args->{option}; # stackable

	# And use them to set status flags.
	if (setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option})) {
		$mustAdd = 0;
	}


	#### Step 3: Add actor to actor list ####
	if ($mustAdd) {
		if (UNIVERSAL::isa($actor, "Actor::Player")) {
			$playersList->add($actor);
			Plugins::callHook('add_player_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Monster")) {
			$monstersList->add($actor);
			Plugins::callHook('add_monster_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Pet")) {
			$petsList->add($actor);
			Plugins::callHook('add_pet_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Portal")) {
			$portalsList->add($actor);
			Plugins::callHook('add_portal_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::NPC")) {
			my $ID = $args->{ID};
			my $location = $field->baseName . " $actor->{pos}{x} $actor->{pos}{y}";
			if ($npcs_lut{$location}) {
				$actor->setName($npcs_lut{$location});
			}
			$npcsList->add($actor);
			Plugins::callHook('add_npc_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Slave")) {
			$slavesList->add($actor);
			Plugins::callHook('add_slave_list', $actor);
		} elsif (UNIVERSAL::isa($actor, "Actor::Elemental")) {
			$elementalsList->add($actor);
			Plugins::callHook('add_elemental_list', $actor);

		} 
	}


	#### Packet specific ####
	if ($args->{switch} eq "0078" ||
		$args->{switch} eq "01D8" ||
		$args->{switch} eq "022A" ||
		$args->{switch} eq "02EE" ||
		$args->{switch} eq "07F9" ||
		$args->{switch} eq "0915" ||
		$args->{switch} eq "09DD" ||
		$args->{switch} eq "09FF") {
		# Actor Exists (standing)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $actor->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsFrom{x}, $coordsFrom{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibility

			Plugins::callHook('player_exist', {player => $actor});

		} elsif ($actor->isa('Actor::NPC')) {
			message TF("NPC Exists: %s (%d, %d) (ID %d) - (%d)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{nameID}, $actor->{binID}), ($config{showDomain_NPC}?$config{showDomain_NPC}:"parseMsg_presence"), 1;
			Plugins::callHook('npc_exist', {npc => $actor});

		} elsif ($actor->isa('Actor::Portal')) {
			message TF("Portal Exists: %s (%s, %s) - (%s)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{binID}), "portals", 1;
			Plugins::callHook('portal_exist', {portal => $actor});
			
		} elsif ($actor->isa('Actor::Monster')) {
			debug sprintf("Monster Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Pet')) {
			debug sprintf("Pet Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Slave')) {
			debug sprintf("Slave Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Elemental')) {
			debug sprintf("Elemental Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} else {
			debug sprintf("Unknown Actor Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;
		}

	} elsif ($args->{switch} eq "0079" ||
		$args->{switch} eq "01DB" ||
		$args->{switch} eq "022B" ||
		$args->{switch} eq "02ED" ||
		$args->{switch} eq "01D9" ||
		$args->{switch} eq "07F8" ||
		$args->{switch} eq "0858" ||
		$args->{switch} eq "090F" ||
		$args->{switch} eq "09DC" ||
		$args->{switch} eq "09FE") {
		# Actor Connected (new)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$actor->name." ($actor->{binID}) Level $args->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsTo{x}, $coordsTo{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibailty

			Plugins::callHook('player_connected', {player => $actor});
		} else {
			debug "Unknown Connected: $args->{type} - \n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007B" ||
		$args->{switch} eq "0086" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C" ||
		$args->{switch} eq "02EC" ||
		$args->{switch} eq "07F7" ||
		$args->{switch} eq "0856" ||
		$args->{switch} eq "0914" ||
		$args->{switch} eq "09DB" ||
		$args->{switch} eq "09FD") {
		# Actor Moved

		# Correct the direction in which they're looking
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		$actor->{look}{body} = $direction;
		$actor->{look}{head} = 0;

		if ($actor->isa('Actor::Player')) {
			debug "Player Moved: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('player_moved', $actor);
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('monster_moved', $actor);
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('pet_moved', $actor);
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('slave_moved', $actor);
		} elsif ($actor->isa('Actor::Portal')) {
			# This can never happen of course.
			debug "Portal Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('portal_moved', $actor);
		} elsif ($actor->isa('Actor::NPC')) {
			# Neither can this.
			debug "NPC Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('npc_moved', $actor);
		} elsif ($actor->isa('Actor::Elemental')) {
			debug "Elemental Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		        Plugins::callHook('pet_moved', $actor);
		} else {
			debug "Unknown Actor Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007C") {
		# Actor Spawned
		if ($actor->isa('Actor::Player')) {
			debug "Player Spawned: " . $actor->nameIdx . " $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Spawned: " . $actor->nameIdx . " $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# Can this happen?
			debug "Portal Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Elemental')) {
			debug "Elemental Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('NPC')) {
			debug "NPC Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} else {
			debug "Unknown Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		}
	}
	
	if($char->{elemental}{ID} eq $actor->{ID}) {
		$char->{elemental} = $actor;
	}
}

sub actor_died_or_disappeared {
	my ($self,$args) = @_;
	return unless changeToInGameState();
	my $ID = $args->{ID};
	avoidList_ID($ID);

	if ($ID eq $accountID) {
		message T("You have died\n") if (!$char->{dead});
		Plugins::callHook('self_died');
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || AI::state == AI::OFF;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;
		if ($char->{equipment}{arrow} && $char->{equipment}{arrow}{type} == 19) {
			delete $char->{equipment}{arrow};
		}

	} elsif (defined $monstersList->getByID($ID)) {
		my $monster = $monstersList->getByID($ID);
		if ($args->{type} == 0) {
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: " . $monster->name . " ($monster->{binID})\n", "parseMsg_damage";
			$monster->{dead} = 1;

			if ((AI::action ne "attack" || AI::args(0)->{ID} eq $ID) &&
			    ($config{itemsTakeAuto_party} &&
			    ($monster->{dmgFromParty} > 0 ||
			     $monster->{dmgFromYou} > 0))) {
				AI::clear("items_take");
				ai_items_take($monster->{pos}{x}, $monster->{pos}{y},
					$monster->{pos_to}{x}, $monster->{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{teleported} = 1;
		}

		$monster->{gone_time} = time;
		$monsters_old{$ID} = $monster->deepCopy();
		Plugins::callHook('monster_disappeared', {monster => $monster});
		$monstersList->remove($monster);

	} elsif (defined $playersList->getByID($ID)) {
		my $player = $playersList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Player Died: %s (%d) %s %s\n", $player->name, $player->{binID}, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}});
			$player->{dead} = 1;
			$player->{dead_time} = time;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: " . $player->name . " ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{teleported} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			}

			if (grep { $ID eq $_ } @venderListsID) {
				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};
			}

			$player->{gone_time} = time;
			$players_old{$ID} = $player->deepCopy();
			Plugins::callHook('player_disappeared', {player => $player});

			$playersList->remove($player);
		}

	} elsif ($players_old{$ID}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{disconnected} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{teleported} = 1;
		}

	} elsif (defined $portalsList->getByID($ID)) {
		my $portal = $portalsList->getByID($ID);
		debug "Portal Disappeared: " . $portal->name . " ($portal->{binID})\n", "parseMsg";
		$portal->{disappeared} = 1;
		$portal->{gone_time} = time;
		$portals_old{$ID} = $portal->deepCopy();
		Plugins::callHook('portal_disappeared', {portal => $portal});
		$portalsList->remove($portal);

	} elsif (defined $npcsList->getByID($ID)) {
		my $npc = $npcsList->getByID($ID);
		debug "NPC Disappeared: " . $npc->name . " ($npc->{nameID})\n", "parseMsg";
		$npc->{disappeared} = 1;
		$npc->{gone_time} = time;
		$npcs_old{$ID} = $npc->deepCopy();
		Plugins::callHook('npc_disappeared', {npc => $npc});
		$npcsList->remove($npc);

	} elsif (defined $petsList->getByID($ID)) {
		my $pet = $petsList->getByID($ID);
		debug "Pet Disappeared: " . $pet->name . " ($pet->{binID})\n", "parseMsg";
		$pet->{disappeared} = 1;
		$pet->{gone_time} = time;
		Plugins::callHook('pet_disappeared', {pet => $pet});
		$petsList->remove($pet);

	} elsif (defined $slavesList->getByID($ID)) {
		my $slave = $slavesList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Slave Died: %s (%d) %s\n", $slave->name, $slave->{binID}, $slave->{actorType});
			$slave->{state} = 4;
		} else {
			if ($args->{type} == 0) {
				debug "Slave Disappeared: " . $slave->name . " ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Slave Disconnected: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Slave Teleported: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{teleported} = 1;
			} else {
				debug "Slave Disappeared in an unknown way: ".$slave->name." ($slave->{binID}) $slave->{actorType}\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			}

			$slave->{gone_time} = time;
			Plugins::callHook('slave_disappeared', {slave => $slave});
		}

		$slavesList->remove($slave);

	} elsif (defined $elementalsList->getByID($ID)) {
		my $elemental = $elementalsList->getByID($ID);
		if ($args->{type} == 0) {
			message "Elemental Disappeared: " .$elemental->{name}. " ($elemental->{binID}) $elemental->{actorType} ($elemental->{pos_to}{x}, $elemental->{pos_to}{y})\n", "parseMsg_presence";
			$elemental->{disappeared} = 1;
		} else {
			debug "Elemental Disappeared in an unknown way: ".$elemental->{name}." ($elemental->{binID}) $elemental->{actorType}\n", "parseMsg_presence";
			$elemental->{disappeared} = 1;
		}

		$elemental->{gone_time} = time;
		Plugins::callHook('elemental_disappeared', {elemental => $elemental});


		if($char->{elemental}{ID} eq $ID) {
			$char->{elemental} = undef;
		}

		$elementalsList->remove($elemental);

	} else {
		debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
	}
}

sub actor_action {
	my ($self,$args) = @_;
	return unless changeToInGameState();

	$args->{damage} = intToSignedShort($args->{damage});
	if ($args->{type} == ACTION_ITEMPICKUP) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';

		my $item = $itemsList->getByID($args->{targetID});
		$item->{takenBy} = $args->{sourceID} if ($item);

	} elsif ($args->{type} == ACTION_SIT) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are sitting.\n") if (!$char->{sitting});
			$char->{sitting} = 1;
			AI::queue("sitAuto") unless (AI::inQueue("sitAuto")) || $ai_v{sitAuto_forcedBySitCommand};
		} else {
			message TF("%s is sitting.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 1 if ($player);
		}
		Misc::checkValidity("actor_action (take item)");

	} elsif ($args->{type} == ACTION_STAND) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are standing.\n") if ($char->{sitting});
			if ($config{sitAuto_idle}) {
				$timeout{ai_sit_idle}{time} = time;
			}
			$char->{sitting} = 0;
		} else {
			message TF("%s is standing.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 0 if ($player);
		}
		Misc::checkValidity("actor_action (stand)");

	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{dual_wield_damage};
		if ($totalDamage == 0) {
			$dmgdisplay = T("Miss!");
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_LUCKY); # lucky dodge
		} else {
			$dmgdisplay = $args->{div} > 1
				? sprintf '%d*%d', $args->{damage} / $args->{div}, $args->{div}
				: $args->{damage}
			;
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_CRITICAL); # critical hit
			$dmgdisplay .= " + $args->{dual_wield_damage}" if $args->{dual_wield_damage};
		}

		Misc::checkValidity("actor_action (attack 1)");

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);

		Misc::checkValidity("actor_action (attack 2)");

		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == ACTION_ATTACK_NOMOTION || $args->{type} == ACTION_ATTACK_MULTIPLE_NOMOTION || $totalDamage == 0;

		my $msg = attack_string($source, $target, $dmgdisplay, ($args->{src_speed}));
		Plugins::callHook('packet_attack', {sourceID => $args->{sourceID}, targetID => $args->{targetID}, msg => \$msg, dmg => $totalDamage, type => $args->{type}});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		Misc::checkValidity("actor_action (attack 3)");

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			Misc::checkValidity("actor_action (attack 4)");
			calcStat($args->{damage});
			Misc::checkValidity("actor_action (attack 5)");

		} elsif ($args->{targetID} eq $accountID) {
			message("$status $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");
			if ($args->{damage} > 0) {
				$damageTaken{$source->{name}}{attack} += $args->{damage};
			}

		} elsif ($char->{slaves} && $char->{slaves}{$args->{sourceID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{sourceID}}{hpPercent}, $char->{slaves}{$args->{sourceID}}{spPercent}) . " $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");

		} elsif ($char->{slaves} && $char->{slaves}{$args->{targetID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{targetID}}{hpPercent}, $char->{slaves}{$args->{targetID}}{spPercent}) . " $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");

		} elsif ($args->{sourceID} eq $args->{targetID}) {
			message("$status $msg");

		} elsif ($config{showAllDamage}) {
			message("$status $msg");

		} else {
			debug("$msg", 'parseMsg_damage');
		}

		Misc::checkValidity("actor_action (attack 6)");
	}
}

sub actor_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	debug "Received object info: $args->{name}\n", "parseMsg_presence/name", 2;
	my $player = $playersList->getByID($args->{ID});
	if ($player) {
		# 0095: This packet tells us the names of players who aren't in a guild.
		# 0195: Receive names of players who are in a guild.
		# FIXME: There is more to this packet than just party name and guild name.
		# This packet is received when you leave a guild
		# (with cryptic party and guild name fields, at least for now)
		$player->setName(bytesToString($args->{name}));
		$player->{info} = 1;

		$player->{party}{name} = bytesToString($args->{partyName}) if defined $args->{partyName};
		$player->{guild}{name} = bytesToString($args->{guildName}) if defined $args->{guildName};
		$player->{guild}{title} = bytesToString($args->{guildTitle}) if defined $args->{guildTitle};
		$player->{title}{ID} = $args->{titleID} if defined $args->{titleID};
		message "Player Info: " . $player->nameIdx . "\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		Plugins::callHook('charNameUpdate', {player => $player});
	}

	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		my $name = bytesToString($args->{name});
		$name =~ s/^\s+|\s+$//g;
		debug "Monster Info: $name ($monster->{binID})\n", "parseMsg", 2;
		$monster->{name_given} = $name;
		$monster->{info} = 1;
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->setName($name);
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT(Settings::getTableFilename("monsters.txt"), $monster->{nameID}, $name);
			Plugins::callHook('mobNameUpdate', {monster => $monster});
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc) {
		$npc->setName(bytesToString($args->{name}));
		$npc->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = $field->baseName . " $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT(Settings::getTableFilename("npcs.txt"), $location, $npc->{name});
		}
		Plugins::callHook('npcNameUpdate', {npc => $npc});
	}

	my $pet = $pets{$args->{ID}};
	if ($pet) {
		my $name = bytesToString($args->{name});
		$pet->{name_given} = $name;
		$pet->setName($name);
		$pet->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
		Plugins::callHook('petNameUpdate', {pet => $pet});
	}

	my $slave = $slavesList->getByID($args->{ID});
	if ($slave) {
		my $name = bytesToString($args->{name});
		$slave->{name_given} = $name;
		$slave->setName($name);
		$slave->{info} = 1;
		my $binID = binFind(\@slavesID, $args->{ID});
		debug "Slave Info: $name ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($slave);
		Plugins::callHook('slaveNameUpdate', {slave => $slave});
	}

	my $elemental = $elementals{$args->{ID}};
	if ($elemental) {
		my $name = bytesToString($args->{name});
		$elemental->{name_given} = $name;
		$elemental->setName($name);
		$elemental->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@elementalsID, $args->{ID});
			debug "elemental Info: $elemental->{name_given} ($binID)\n", "parseMsg", 2;
		}
		Plugins::callHook('elementalNameUpdate', {elemental => $elemental});
	}
	
	# TODO: $args->{ID} eq $accountID
}

use constant QTYPE => (
	0x0 => [0xff, 0xff, 0, 0],
	0x1 => [0xff, 0x80, 0, 0],
	0x2 => [0, 0xff, 0, 0],
	0x3 => [0x80, 0, 0x80, 0],
);

sub parse_minimap_indicator {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{npcID});
	$args->{show} = $args->{type} != 2;

	unless (defined $args->{red}) {
		@{$args}{qw(red green blue alpha)} = @{{QTYPE}->{$args->{qtype}} || [0xff, 0xff, 0xff, 0]};
	}

	# FIXME: packet 0144: coordinates are missing now when clearing indicators; ID is used
	# Wx depends on coordinates there
}

sub account_payment_info {
	my ($self, $args) = @_;
	my $D_minute = $args->{D_minute};
	my $H_minute = $args->{H_minute};

	my $D_d = int($D_minute / 1440);
	my $D_h = int(($D_minute % 1440) / 60);
	my $D_m = int(($D_minute % 1440) % 60);

	my $H_d = int($H_minute / 1440);
	my $H_h = int(($H_minute % 1440) / 60);
	my $H_m = int(($H_minute % 1440) % 60);

	message  T("============= Account payment information =============\n"), "info";
	message TF("Pay per day  : %s day(s) %s hour(s) and %s minute(s)\n", $D_d, $D_h, $D_m), "info";
	message TF("Pay per hour : %s day(s) %s hour(s) and %s minute(s)\n", $H_d, $H_h, $H_m), "info";
	message  "-------------------------------------------------------\n", "info";
}

# TODO
sub reconstruct_minimap_indicator {
}

use constant {
	HO_PRE_INIT => 0x0,
	HO_RELATIONSHIP_CHANGED => 0x1,
	HO_FULLNESS_CHANGED => 0x2,
	HO_ACCESSORY_CHANGED => 0x3,
	HO_HEADTYPE_CHANGED => 0x4,
};

# 0230
# TODO: what is type?
sub homunculus_info {
	my ($self, $args) = @_;
	debug "homunculus_info type: $args->{type}\n", "homunculus";
	if ($args->{state} == HO_PRE_INIT) {
		my $state = $char->{homunculus}{state}
			if ($char->{homunculus} && $char->{homunculus}{ID} && $char->{homunculus}{ID} ne $args->{ID});
		$char->{homunculus} = Actor::get($args->{ID}) if ($char->{homunculus}{ID} ne $args->{ID});
		$char->{homunculus}{state} = $state if (defined $state);
		$char->{homunculus}{map} = $field->baseName;
		unless ($char->{slaves}{$char->{homunculus}{ID}}) {
			AI::SlaveManager::addSlave ($char->{homunculus});
			$char->{homunculus}{appear_time} = time;
		}
	} elsif ($args->{state} == HO_RELATIONSHIP_CHANGED) {
		$char->{homunculus}{intimacy} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_FULLNESS_CHANGED) {
		$char->{homunculus}{hunger} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_ACCESSORY_CHANGED) {
		$char->{homunculus}{accessory} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_HEADTYPE_CHANGED) {
		#
	}
}

##
# minimap_indicator({bool show, Actor actor, int x, int y, int red, int green, int blue, int alpha [, int effect]})
# show: whether indicator is shown or cleared
# actor: @MODULE(Actor) who issued the indicator; or which Actor it's binded to
# x, y: indicator coordinates
# red, green, blue, alpha: indicator color
# effect: unknown, may be missing
#
# Minimap indicator.
sub minimap_indicator {
	my ($self, $args) = @_;

	my $color_str = "[R:$args->{red}, G:$args->{green}, B:$args->{blue}, A:$args->{alpha}]";
	my $indicator = T("minimap indicator");
	if (defined $args->{type}) {
		unless ($args->{type} == 1 || $args->{type} == 2) {
			$indicator .= TF(" (unknown type %d)", $args->{type});
		}
	} elsif (defined $args->{effect}) {
		if ($args->{effect} == 1) {
			$indicator = T("*Quest!*");
		} elsif ($args->{effect}) { # 0 is no effect
			$indicator = TF("unknown effect %d", $args->{effect});
		}
	}

	if ($args->{show}) {
		message TF("%s shown %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	} else {
		message TF("%s cleared %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	}
}

# 0x01B3
sub parse_npc_image {
	my ($self, $args) = @_;

	$args->{npc_image} = bytesToString($args->{npc_image});
}

sub reconstruct_npc_image {
	my ($self, $args) = @_;

	$args->{npc_image} = stringToBytes($args->{npc_image});
}

sub npc_image {
	my ($self, $args) = @_;

	if ($args->{type} == 2) {
		message TF("NPC image: %s\n", $args->{npc_image}), 'npc';
	} elsif ($args->{type} == 255) {
		debug "Hide NPC image: $args->{npc_image}\n", "parseMsg";
	} else {
		message TF("NPC image: %s (unknown type %s)\n", $args->{npc_image}, $args->{type}), 'npc';
	}

	unless ($args->{type} == 255) {
		$talk{image} = $args->{npc_image};
	} else {
		delete $talk{image};
	}
}

sub local_broadcast {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $color = uc(sprintf("%06x", $args->{color})); # hex code
	stripLanguageCode(\$message);
	chatLog("lb", "$message\n");# if ($config{logLocalBroadcast});
	message "$message\n", "schat";
	Plugins::callHook('packet_localBroadcast', {
		Msg => $message,
		color => $color
	});
}

sub parse_sage_autospell {
	my ($self, $args) = @_;

	$args->{skills} = [map { Skill->new(idn => $_) } sort { $a<=>$b } grep {$_}
		exists $args->{autoshadowspell_list}
		? (unpack 'v*', $args->{autoshadowspell_list})
		: (unpack 'V*', $args->{autospell_list})
	];
}

sub reconstruct_sage_autospell {
	my ($self, $args) = @_;

	my @skillIDs = map { $_->getIDN } $args->{skills};
	$args->{autoshadowspell_list} = pack 'v*', @skillIDs;
	$args->{autospell_list} = pack 'V*', @skillIDs;
}

##
# sage_autospell({arrayref skills, int why})
# skills: list of @MODULE(Skill) instances
# why: unknown
#
# Skill list for Sage's Hindsight and Shadow Chaser's Auto Shadow Spell.
sub sage_autospell {
	my ($self, $args) = @_;

	return unless $self->changeToInGameState;

	my $msg = center(' ' . T('Auto Spell') . ' ', 40, '-') . "\n"
	. T("   # Skill\n")
	. (join '', map { swrite '@>>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<', [$_->getIDN, $_] } @{$args->{skills}})
	. ('-'x40) . "\n";

	message $msg, 'list';

	if ($config{autoSpell}) {
		my @autoSpells = split /\s*,\s*/, $config{autoSpell};
		for my $autoSpell (@autoSpells) {
			my $skill = new Skill(auto => $autoSpell);
			message 'Testing autoSpell ' . $autoSpell . "\n";
			if (!$config{autoSpell_safe} || List::Util::first { $_->getIDN == $skill->getIDN } @{$args->{skills}}) {
				if (defined $args->{why}) {
					$messageSender->sendSkillSelect($skill->getIDN, $args->{why});
					return;
				} else {
					$messageSender->sendAutoSpell($skill->getIDN);
					return;
				}
			}
		}
		error TF("Configured autoSpell (%s) not available.\n", $config{autoSpell});
		message T("Disable autoSpell_safe to use it anyway.\n"), 'hint';
	} else {
		message T("Configure autoSpell to automatically select skill for Auto Spell.\n"), 'hint';
	}
}

sub show_eq {
	my ($self, $args) = @_;
	my $item_info;
	my @item;
	
	if ($args->{switch} eq '02D7') {  # PACKETVER DEFAULT	
		$item_info = {
			len => 26,
			types => 'a2 v C2 v2 C2 a8 l v',
			keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType)],
		};
		
		if (exists $args->{robe}) {  # PACKETVER >= 20100629
			$item_info->{type} .= 'v';
			$item_info->{len} += 2;
		}
		
	} elsif ($args->{switch} eq '0906') {  # PACKETVER >= ?? NOT IMPLEMENTED ON EATHENA BASED EMULATOR	
		$item_info = {
			len => 27,
			types => 'v2 C v2 C a8 l v2 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
		};

	} elsif ($args->{switch} eq '0859') { # PACKETVER >= 20101124	
		$item_info = {
			len => 28,
			types => 'a2 v C2 v2 C2 a8 l v2',
			keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType sprite_id)],
		};
		
	} elsif ($args->{switch} eq '0997') { # PACKETVER >= 20120925
		$item_info = {
			len => 31,
			types => 'a2 v C V2 C a8 l v2 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
		};
		
	} elsif ($args->{switch} eq '0A2D') { # PACKETVER >= 20150226
		$item_info = {
			len => 57,
			types => 'a2 v C V2 C a8 l v2 C a25 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified)],
		};
	} else { # this can't happen
		return; 
	}
	
	message "--- $args->{name} Equip Info --- \n";

	for (my $i = 0; $i < length($args->{equips_info}); $i += $item_info->{len}) {
		my $item;		
		@{$item}{@{$item_info->{keys}}} = unpack($item_info->{types}, substr($args->{equips_info}, $i, $item_info->{len}));			
		$item->{broken} = 0;
		$item->{identified} = 1;		
		message sprintf("%-20s: %s\n", $equipTypes_lut{$item->{equipped}}, itemName($item)), "list";
	}
	
	message "----------------- \n";
	
}

sub show_eq_msg_other {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Allowed to view the other player's Equipment.\n");
	} else {
		message T("Not allowed to view the other player's Equipment.\n");
	}
}

sub show_eq_msg_self {
	my ($self, $args) = @_;
	if ($args->{type}) {
		message T("Other players are allowed to view your Equipment.\n");
	} else {
		message T("Other players are not allowed to view your Equipment.\n");
	}
}

# 043D
sub skill_post_delay {
	my ($self, $args) = @_;

	my $skillName = (new Skill(idn => $args->{ID}))->getName;
	my $status = defined $statusName{'EFST_DELAY'} ? $statusName{'EFST_DELAY'} : 'Delay';

	$char->setStatus($skillName." ".$status, 1, $args->{time});
}

# TODO: known prefixes (chat domains): micc | ssss | blue | tool
# micc = micc<24 characters, this is the sender name. seems like it's null padded><hex color code><message>
# micc = Player Broadcast   The struct: micc<23bytes player name+some hex><\x00><colour code><full message>
# The first player name is used for detecting the player name only according to the disassembled client.
# The full message contains the player name at the first 22 bytes
# TODO micc.* is currently unstricted, however .{24} and .{23} do not detect chinese with some reasons, please improve this regex if necessary
sub system_chat {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $prefix;
	my $color;
	if ($message =~ s/^ssss//g) {  # forces color yellow, or WoE indicator?
		$prefix = T('[WoE]');
	} elsif ($message =~ /^micc.*\0\0([0-9a-fA-F]{6})(.*)/) { #appears in twRO   ## [micc][name][\x00\x00][unknown][\x00\x00][color][name][blablabla][message]
		($color, $message) = $message =~ /^micc.*\0\0([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} elsif ($message =~ /^micc.{12,24}([0-9a-fA-F]{6})(.*)/) {
		($color, $message) = $message =~ /^micc.*([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} elsif ($message =~ s/^blue//g) {  # forces color blue
		$prefix = T('[S]');
	} elsif ($message =~ /^tool([0-9a-fA-F]{6})(.*)/) {
		($color, $message) = $message =~ /^tool([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} else {
		$prefix = T('[S]');
	}
	$message =~ s/\000//g; # remove null charachters
	$message =~ s/^ +//g; $message =~ s/ +$//g; # remove whitespace in the beginning and the end of $message
	stripLanguageCode(\$message);
	chatLog("s", "$message\n") if ($config{logSystemChat});
	# Translation Comment: System/GM chat
	message "$prefix $message\n", "schat";
	ChatQueue::add('gm', undef, undef, $message) if ($config{callSignGM});

	Plugins::callHook('packet_sysMsg', {
		Msg => $message,
		MsgColor => $color,
		MsgUser => undef # TODO: implement this value, we can get this from "micc" messages by regex.
	});
}

sub warp_portal_list {
	my ($self, $args) = @_;

	# strip gat extension
	($args->{memo1}) = $args->{memo1} =~ /^(.*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /^(.*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /^(.*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /^(.*)\.gat/;
	# Auto-detect saveMap
	if ($args->{type} == 26) {
		configModify('saveMap', $args->{memo2}) if ($args->{memo2} && $config{'saveMap'} ne $args->{memo2});
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if ($args->{memo1} && $config{'saveMap'} ne $args->{memo1});
		configModify( "memo$_", $args->{"memo$_"} ) foreach grep { $args->{"memo$_"} ne $config{"memo$_"} } 1 .. 4;
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

	my $msg = center(T(" Warp Portal "), 50, '-') ."\n".
		T("#  Place                           Map\n");
	for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
			[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'}, $char->{warp}{memo}[$i]]);
	}
	$msg .= ('-'x50) . "\n";
	message $msg, "list";
	
	if ($args->{type} == 26 && AI::inQueue('teleport')) {
		# We have already successfully used the Teleport skill.
		$messageSender->sendWarpTele(26, AI::args->{lv} == 2 ? "$config{saveMap}.gat" : "Random");
		AI::dequeue;
	}
}


# 0828,14
sub char_delete2_result {
	my ($self, $args) = @_;
	my $result = $args->{result};
	my $deleteDate = $args->{deleteDate};

	if ($result && $deleteDate) {
		setCharDeleteDate($messageSender->{char_delete_slot}, $deleteDate);
		message TF("Your character will be delete, left %s\n", $chars[$messageSender->{char_delete_slot}]{deleteDate}), "connection";
	} elsif ($result == 0) {
		error T("That character already planned to be erased!\n");
	} elsif ($result == 3) {
		error T("Error in database of the server!\n");
	} elsif ($result == 4) {
		error T("To delete a character you must withdraw from the guild!\n");
	} elsif ($result == 5) {
		error T("To delete a character you must withdraw from the party!\n");
	} else {
		error TF("Unknown error when trying to delete the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 082A,10
sub char_delete2_accept_result {
	my ($self, $args) = @_;
	my $charID = $args->{charID};
	my $result = $args->{result};

	if ($result == 1) { # Success
		if (defined $AI::temp::delIndex) {
			message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
			delete $chars[$AI::temp::delIndex];
			undef $AI::temp::delIndex;
			for (my $i = 0; $i < @chars; $i++) {
				delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
			}
		} else {
			message T("Character deleted.\n"), "info";
		}

		if (charSelectScreen() == 1) {
			$net->setState(3);
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
		return;
	} elsif ($result == 0) {
		error T("Enter your 6-digit birthday (YYMMDD) (e.g: 801122).\n");
	} elsif ($result == 2) {
		error T("Due to system settings, can not be deleted.\n");
	} elsif ($result == 3) {
		error T("A database error has occurred.\n");
	} elsif ($result == 4) {
		error T("You cannot delete this character at the moment.\n");
	} elsif ($result == 5) {
		error T("Your entered birthday does not match.\n");
	} elsif ($result == 7) {
		error T("Character Deletion has failed because you have entered an incorrect e-mail address.\n");
	} else {
		error TF("An unknown error has occurred. Error number %d\n", $result);
	}

	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# 082C,14
sub char_delete2_cancel_result {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result) {
		message T("Character is no longer scheduled to be deleted\n"), "connection";
		$chars[$messageSender->{char_delete_slot}]{deleteDate} = '';
	} elsif ($result == 2) {
		error T("Error in database of the server!\n");
	} else {
		error TF("Unknown error when trying to cancel the deletion of the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 013C
sub arrow_equipped {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	return unless $args->{ID};
	$char->{arrow} = $args->{ID};

	my $item = $char->inventory->getByID($args->{ID});
	if ($item && $char->{equipment}{arrow} != $item) {
		$char->{equipment}{arrow} = $item;
		$item->{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message TF("Arrow/Bullet equipped: %s (%d) x %s\n", $item->{name}, $item->{binID}, $item->{amount});
		Plugins::callHook('equipped_item', {slot => 'arrow', item => $item});
	}
}

# 00AF, 07FA
sub inventory_item_removed {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	my $reason = $args->{reason};

	if ($reason) {
		if ($reason == 1) {
			debug TF("%s was used to cast the skill\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 2) {
			debug TF("%s broke due to the refinement failed\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 3) {
			debug TF("%s used in a chemical reaction\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 4) {
			debug TF("%s was moved to the storage\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 5) {
			debug TF("%s was moved to the cart\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 6) {
			debug TF("%s was sold\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 7) {
			debug TF("%s was consumed by Four Spirit Analysis skill\n", $item->{name}), "inventory", 1;
		} else {
			debug TF("%s was consumed by an unknown reason (reason number %s)\n", $item->{name}, $reason), "inventory", 1;
		}
	}

	if ($item) {
		inventoryItemRemoved($item->{binID}, $args->{amount});
		Plugins::callHook('packet_item_removed', {index => $item->{binID}});
	}
}

# 012B
sub cart_off {
	$char->cart->close;
	message T("Cart released.\n"), "success";
}

# 012D
sub shop_skill {
	my ($self, $args) = @_;

	# Used the shop skill.
	my $number = $args->{number};
	message TF("You can sell %s items!\n", $number);
}

# Your shop has sold an item -- one packet sent per item sold.
#
sub shop_sold {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};

	$articles[$number]{sold} += $amount;
	my $earned = $amount * $articles[$number]{price};
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;
	my $msg = TF("Sold: %s x %s - %sz\n", $articles[$number]{name}, $amount, $earned);
	shopLog($msg) if $config{logShop};
	message($msg, "sold");

	# Call hook before we possibly remove $articles[$number] or
	# $articles itself as a result of the sale.
	Plugins::callHook(
		'vending_item_sold',
		{
			'vendShopIndex' => $number,
			'amount' => $amount,
			'vendArticle' => $articles[$number], #This is a hash
			'zenyEarned' => $earned,
			'packetType' => "short",
		}
	);

	# Adjust the shop's articles for sale, and notify if the sold
	# item and/or the whole shop has been sold out.
	if ($articles[$number]{quantity} < 1) {
		message TF("Sold out: %s\n", $articles[$number]{name}), "sold";
		Plugins::callHook(
			'vending_item_sold_out',
			{
				'vendShopIndex' => $number,
				'vendArticle' => $articles[$number],
			}
		);
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

sub shop_sold_long {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};
	my $earned = $args->{zeny};
	my $charID = getHex($args->{charID});
	my $when = $args->{time};

	$articles[$number]{sold} += $amount;
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;
	
	my $msg = TF("Sold: %s x %s - %sz (Buyer charID: %s)\n", $articles[$number]{name}, $amount, $earned, $charID);
	shopLog($msg) if $config{logShop};
	message("[" . getFormattedDate($when) . "] " . $msg, "sold");

	# Call hook before we possibly remove $articles[$number] or
	# $articles itself as a result of the sale.
	Plugins::callHook(
		'vending_item_sold',
		{
			'vendShopIndex' => $number,
			'amount' => $amount,
			'vendArticle' => $articles[$number], #This is a hash
			'buyerCharID' => $args->{charID},
			'zenyEarned' => $earned,
			'time' => $when,
			'packetType' => "long",
		}
	);

	# Adjust the shop's articles for sale, and notify if the sold
	# item and/or the whole shop has been sold out.
	if ($articles[$number]{quantity} < 1) {
		message TF("Sold out: %s\n", $articles[$number]{name}), "sold";
		Plugins::callHook(
			'vending_item_sold_out',
			{
				'vendShopIndex' => $number,
				'vendArticle' => $articles[$number],
			}
		);
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

# 01D0 (spirits), 01E1 (coins), 08CF (amulets)
sub revolving_entity {
	my ($self, $args) = @_;

	# Monk Spirits or Gunslingers' coins or senior ninja
	my $sourceID = $args->{sourceID};
	my $entityNum = $args->{entity};
	my $entityElement = $elements_lut{$args->{type}} if ($args->{type} && $entityNum);
	my $entityType;

	my $actor = Actor::get($sourceID);
	if ($args->{switch} eq '01D0') {
		# Translation Comment: Spirit sphere of the monks
		$entityType = T('spirit');
	} elsif ($args->{switch} eq '01E1') {
		# Translation Comment: Coin of the gunslinger
		$entityType = T('coin');
	} elsif ($args->{switch} eq '08CF') {
		# Translation Comment: Amulet of the warlock
		$entityType = T('amulet');
	} else {
		$entityType = T('entity unknown');
	}

	if ($sourceID eq $accountID && $entityNum != $char->{spirits}) {
		$char->{spirits} = $entityNum;
		$char->{amuletType} = $entityElement;
		$char->{spiritsType} = $entityType;
		$entityElement ?
			# Translation Comment: Message displays following: quantity, the name of the entity and its element
			message TF("You have %s %s(s) of %s now\n", $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: quantity and the name of the entity
			message TF("You have %s %s(s) now\n", $entityNum, $entityType), "parseMsg_statuslook", 1;
	} elsif ($entityNum != $actor->{spirits}) {
		$actor->{spirits} = $entityNum;
		$actor->{amuletType} = $entityElement;
		$actor->{spiritsType} = $entityType;
		$entityElement ?
			# Translation Comment: Message displays following: actor, quantity, the name of the entity and its element
			message TF("%s has %s %s(s) of %s now\n", $actor, $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: actor, quantity and the name of the entity
			message TF("%s has %s %s(s) now\n", $actor, $entityNum, $entityType), "parseMsg_statuslook", 1;
	}
}

# 0977
sub monster_hp_info {
	my ($self, $args) = @_;
	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		$monster->{hp} = $args->{hp};
		$monster->{hp_max} = $args->{hp_max};

		debug TF("Monster %s has hp %s/%s (%s%)\n", $monster->name, $monster->{hp}, $monster->{hp_max}, $monster->{hp} * 100 / $monster->{hp_max}), "parseMsg_damage";
	}
}

##
# account_id({accountID})
#
# This is for what eA calls PacketVersion 9, they send the AID in a 'proper' packet
sub account_id {
	my ($self, $args) = @_;
	# the account ID is already unpacked into PLAIN TEXT when it gets to this function...
	# So lets not fuckup the $accountID since we need that later... someone will prolly have to fix this later on
	my $accountID = $args->{accountID};
	debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));
}

##
# marriage_partner_name({String name})
#
# Name of the partner character, sent to everyone around right before casting "I miss you".
sub marriage_partner_name {
	my ($self, $args) = @_;

	message TF("Marriage partner name: %s\n", $args->{name});
}

sub login_pin_code_request {
	# This is ten second-level password login for 2013/3/29 upgrading of twRO
	my ($self, $args) = @_;

	if($args->{flag} ne 0 && ($config{XKore} eq "1" || $config{XKore} eq "3")) {
		$timeout{master}{time} = time;
		return;
	}

	# flags:
	# 0 - correct
	# 1 - requested (already defined)
	# 2 - requested (not defined)
	# 3 - expired
	# 5 - invalid (official servers?)
	# 7 - disabled?
	# 8 - incorrect
	if ($args->{flag} == 0) { # removed check for seed 0, eA/rA/brA sends a normal seed.
		message T("PIN code is correct.\n"), "success";
		# call charSelectScreen
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		message T("Server requested PIN password in order to select your character.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 2) {
		# PIN code has never been set before, so set it.
		warning T("PIN password is not set for this account.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 3) {
		# should we use the same one again? is it possible?
		warning T("PIN password expired.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 5) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		# configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is invalid. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 7) {
		# PIN code disabled.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		# call charSelectScreen
		$self->{lockCharScreen} = 0;
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} elsif ($args->{flag} == 8) {
		# PIN code incorrect.
		error T("PIN code is incorrect.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}

	$timeout{master}{time} = time;
}

sub login_pin_new_code_result {
	my ($self, $args) = @_;

	if ($args->{flag} == 2) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("PIN code is invalid, don't use sequences or repeated numbers.\n"))));

		# there's a bug in bRO where you can use letters or symbols or even a string as your PIN code.
		# as a result this will render you unable to login again (forever?) using the official client
		# and this is detectable and can result in a permanent ban. we're using this code in order to
		# prevent this. - revok 17.12.2012
		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
			!($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}

		$messageSender->sendLoginPinCode($args->{seed}, 0);
	}
}

sub actor_status_active {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $ID, $tick, $unknown1, $unknown2, $unknown3, $unknown4) = @{$args}{qw(type ID tick unknown1 unknown2 unknown3 unknown4)};
	my $flag = (exists $args->{flag}) ? $args->{flag} : 1;
	my $status = defined $statusHandle{$type} ? $statusHandle{$type} : "UNKNOWN_STATUS_$type";
	$char->cart->changeType($unknown1) if ($type == 673 && defined $unknown1 && ($ID eq $accountID)); # for Cart active
	$args->{skillName} = defined $statusName{$status} ? $statusName{$status} : $status;
#	($args->{actor} = Actor::get($ID))->setStatus($status, 1, $tick == 9999 ? undef : $tick, $args->{unknown1}); # need test for '08FF'
	($args->{actor} = Actor::get($ID))->setStatus($status, $flag, $tick == 9999 ? undef : $tick);
	# Rolling Cutter counters.
	if ( $type == 0x153 && $char->{spirits} != $unknown1 ) {
		$char->{spirits} = $unknown1 || 0;
		if ( $ID eq $accountID ) {
			message TF( "You have %s %s(s) now\n", $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		} else {
			message TF( "%s has %s %s(s) now\n", $args->{actor}, $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		}
	}
}

#099B
sub map_property3 {
	my ($self, $args) = @_;

	if($config{'status_mapType'}){
		$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
		grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
		map {[$_, defined $mapTypeHandle{$_} ? $mapTypeHandle{$_} : "UNKNOWN_MAPTYPE_$_"]}
		0 .. List::Util::max $args->{type}, keys %mapTypeHandle;

		if ($args->{info_table}) {
			my $info_table = unpack('V1',$args->{info_table});
			for (my $i = 0; $i < 16; $i++) {
				if ($info_table&(1<<$i)) {
					$char->setStatus(defined $mapPropertyInfoHandle{$i} ? $mapPropertyInfoHandle{$i} : "UNKNOWN_MAPPROPERTY_INFO_$i",1);
				}
			}
		}
	}

	$pvp = {6 => 1, 8 => 2, 19 => 3}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG, 3 Battleground
		});
	}
}

#099F
sub area_spell_multiple2 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $fail);
	for (my $i = 0; $i < $len; $i += 18) {
		$msg = substr($spellInfo, $i, 18);
		($ID, $sourceID, $x, $y, $type, $range, $fail) = unpack('a4 a4 v3 X2 C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}
	
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

#09CA
sub area_spell_multiple3 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $fail);
	for (my $i = 0; $i < $len; $i += 19) {
		$msg = substr($spellInfo, $i, 19);
		($ID, $sourceID, $x, $y, $type, $range, $fail) = unpack('a4 a4 v3 X3 C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}
	
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

sub sync_request_ex {
	my ($self, $args) = @_;
	
	return if($config{XKore} eq 1 || $config{XKore} eq 3); # let the clien hanle this
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Getting Sync Ex Reply ID from Table
	my $SyncID = $self->{sync_ex_reply}->{$PacketID};
	
	# Cleaning Leading Zeros
	$PacketID =~ s/^0+//;	
	
	# Cleaning Leading Zeros	
	$SyncID =~ s/^0+//;
	
	# Debug Log
	#error sprintf("Received Ex Packet ID : 0x%s => 0x%s\n", $PacketID, $SyncID);

	# Converting ID to Hex Number
	$SyncID = hex($SyncID);

	# Dispatching Sync Ex Reply
	$messageSender->sendReplySyncRequestEx($SyncID);
}

sub cash_shop_list {
	my ($self, $args) = @_;
	my $tabcode = $args->{tabcode};
	my $jump = 6;
	my $unpack_string  = "v V";
	# CASHSHOP_TAB_NEW => 0x0,
	# CASHSHOP_TAB_POPULAR => 0x1,
	# CASHSHOP_TAB_LIMITED => 0x2,
	# CASHSHOP_TAB_RENTAL => 0x3,
	# CASHSHOP_TAB_PERPETUITY => 0x4,
	# CASHSHOP_TAB_BUFF => 0x5,
	# CASHSHOP_TAB_RECOVERY => 0x6,
	# CASHSHOP_TAB_ETC => 0x7
	# CASHSHOP_TAB_MAX => 8
	my %cashitem_tab = (
		0 => 'New',
		1 => 'Popular',
		2 => 'Limited',
		3 => 'Rental',
		4 => 'Perpetuity',
		5 => 'Buff',
		6 => 'Recovery',
		7 => 'Etc',
	);
	debug TF("%s\n" .
		"#   Name                               Price\n",
		center(' Tab: ' . $cashitem_tab{$tabcode} . ' ', 44, '-')), "list";
	for (my $i = 0; $i < length($args->{itemInfo}); $i += $jump) {
		my ($ID, $price) = unpack($unpack_string, substr($args->{itemInfo}, $i));
		my $name = itemNameSimple($ID);
		push(@{$cashShop{list}[$tabcode]}, {item_id => $ID, price => $price}); # add to cashshop
		debug(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>C",
			[$i, $name, formatNumber($price)]),
			"list");

		}
}

sub cash_shop_open_result {
	my ($self, $args) = @_;
	#'0845' => ['cash_window_shop_open', 'v2', [qw(cash_points kafra_points)]],
	message TF("Cash Points: %sC - Kafra Points: %sC\n", formatNumber ($args->{cash_points}), formatNumber ($args->{kafra_points}));
	$cashShop{points} = {
							cash => $args->{cash_points},
							kafra => $args->{kafra_points}
						};
}

sub cash_shop_buy_result {
	my ($self, $args) = @_;
		# TODO: implement result messages:
		# SUCCESS			= 0x0,
		# WRONG_TAB?		= 0x1, // we should take care with this, as it's detectable by the server
		# SHORTTAGE_CASH		= 0x2,
		# UNKONWN_ITEM		= 0x3,
		# INVENTORY_WEIGHT		= 0x4,
		# INVENTORY_ITEMCNT		= 0x5,
		# RUNE_OVERCOUNT		= 0x9,
		# EACHITEM_OVERCOUNT		= 0xa,
		# UNKNOWN			= 0xb,
	if ($args->{result} > 0) {
		error TF("Error while buying %s from cash shop. Error code: %s\n", itemNameSimple($args->{item_id}), $args->{result});
	} else {
		message TF("Bought %s from cash shop. Current CASH: %s\n", itemNameSimple($args->{item_id}), formatNumber($args->{updated_points})), "success";
		$cashShop{points}->{cash} = $args->{updated_points};
	}
	
	debug sprintf("Got result ID [%s] while buying %s from CASH Shop. Current CASH: %s \n", $args->{result}, itemNameSimple($args->{item_id}), formatNumber($args->{updated_points}));

	
}

sub player_equipment {
	my ($self, $args) = @_;

	my ($sourceID, $type, $ID1, $ID2) = @{$args}{qw(sourceID type ID1 ID2)};
	my $player = ($sourceID ne $accountID)? $playersList->getByID($sourceID) : $char;
	return unless $player;

	if ($type == 0) {
		# Player changed job
		$player->{jobID} = $ID1;

	} elsif ($type == 2) {
		if ($ID1 ne $player->{weapon}) {
			message TF("%s changed Weapon to %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
			$player->{weapon} = $ID1;
		}
		if ($ID2 ne $player->{shield}) {
			message TF("%s changed Shield to %s\n", $player, itemName({nameID => $ID2})), "parseMsg_statuslook", 2;
			$player->{shield} = $ID2;
		}
	} elsif ($type == 3) {
		$player->{headgear}{low} = $ID1;
	} elsif ($type == 4) {
		$player->{headgear}{top} = $ID1;
	} elsif ($type == 5) {
		$player->{headgear}{mid} = $ID1;
	} elsif ($type == 9) {
		if ($player->{shoes} && $ID1 ne $player->{shoes}) {
			message TF("%s changed Shoes to: %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
		}
		$player->{shoes} = $ID1;
	}
}

sub progress_bar {
	my($self, $args) = @_;
	message TF("Progress bar loading (time: %d).\n", $args->{time}), 'info';
	$char->{progress_bar} = 1;
	$taskManager->add(
		new Task::Chained(tasks => [new Task::Wait(seconds => $args->{time}),
		new Task::Function(function => sub {
			 $messageSender->sendProgress();
			 message TF("Progress bar finished.\n"), 'info';
			 $char->{progress_bar} = 0;
			 $_[0]->setDone;
		})]));
}

sub progress_bar_stop {
	my($self, $args) = @_;
	message TF("Progress bar finished.\n", 'info');
}

# 02B1
sub quest_all_list {
	my ($self, $args) = @_;
	$questList = {};
	for (my $i = 8; $i < $args->{amount}*5+8; $i += 5) {
		my ($questID, $active) = unpack('V C', substr($args->{RAW_MSG}, $i, 5));
		$questList->{$questID}->{active} = $active;
		debug "$questID $active\n", "info";
	}
}

# 02B2
# note: this packet shows all quests + their missions and has variable length
sub quest_all_mission {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	for (my $i = 8; $i < $args->{amount}*104+8; $i += 104) {
		my ($questID, $time_start, $time, $mission_amount) = unpack('V3 v', substr($args->{RAW_MSG}, $i, 14));
		my $quest = \%{$questList->{$questID}};
		$quest->{time_start} = $time_start;
		$quest->{time} = $time;
		debug "$questID $time_start $time $mission_amount\n", "info";
		for (my $j = 0; $j < $mission_amount; $j++) {
			my ($mobID, $count, $mobName) = unpack('V v Z24', substr($args->{RAW_MSG}, 14+$i+$j*30, 30));
			my $mission = \%{$quest->{missions}->{$mobID}};
			$mission->{mobID} = $mobID;
			$mission->{count} = $count;
			$mission->{mobName} = bytesToString($mobName);
			Plugins::callHook('quest_mission_added', {
				questID => $questID,
				mobID => $mobID,
				count => $count
				
			});
			debug "- $mobID $count $mobName\n", "info";
		}
	}
}

# 02B3
# 09F9
# note: this packet shows all missions for 1 quest and has fixed length
sub quest_add {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	my $quest = \%{$questList->{$questID}};

	unless (%$quest) {
		message TF("Quest: %s has been added.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	}

	my $pack = 'a0 V v Z24';
	$pack = 'V x4 V x4 v Z24' if $args->{switch} eq '09F9';
	my $pack_len = length pack $pack, ( 0 ) x 7;

	$quest->{time_start} = $args->{time_start};
	$quest->{time} = $args->{time};
	$quest->{active} = $args->{active};
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	my $o = 17;
	for (my $i = 0; $i < $args->{amount}; $i++) {
		my ( $conditionID, $mobID, $count, $mobName ) = unpack $pack, substr $args->{RAW_MSG}, $o + $i * $pack_len, $pack_len;
		my $mission = \%{$quest->{missions}->{$conditionID || $mobID}};
		$mission->{mobID} = $mobID;
		$mission->{conditionID} = $conditionID;
		$mission->{count} = $count;
		$mission->{mobName} = bytesToString($mobName);
		Plugins::callHook('quest_mission_added', {
				questID => $questID,
				mobID => $mobID,
				count => $count
		});
		debug "- $mobID $count $mobName\n", "info";
	}
}

# 02B4
sub quest_delete {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	message TF("Quest: %s has been deleted.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	delete $questList->{$questID};
}

sub parse_quest_update_mission_hunt {
	my ( $self, $args ) = @_;
	if ( $args->{switch} eq '09FA' ) {
		@{ $args->{mobs} } = map { my %result; @result{qw(questID mobID goal count)} = unpack 'V2 v2', $_; \%result } unpack '(a12)*', $args->{mobInfo};
	} else {
		@{ $args->{mobs} } = map { my %result; @result{qw(questID mobID count)} = unpack 'V2 v', $_; \%result } unpack '(a10)*', $args->{mobInfo};
	}
}

sub reconstruct_quest_update_mission_hunt {
	my ($self, $args) = @_;
	$args->{mobInfo} = pack '(a10)*', map { pack 'V2 v', @{$_}{qw(questID mobID count)} } @{$args->{mobs}};
}

sub parse_quest_update_mission_hunt_v2 {
	my ($self, $args) = @_;
	@{$args->{mobs}} = map {
		my %result; @result{qw(questID mobID goal count)} = unpack 'V2 v2', $_; \%result
	} unpack '(a12)*', $args->{mobInfo};
}

sub reconstruct_quest_update_mission_hunt_v2 {
	my ($self, $args) = @_;
	$args->{mobInfo} = pack '(a12)*', map { pack 'V2 v2', @{$_}{qw(questID mobID goal count)} } @{$args->{mobs}};
}

# 02B5
# 09FA
sub quest_update_mission_hunt {
	my ($self, $args) = @_;
	my ($questID, $mobID, $goal, $count) = unpack('V2 v2', substr($args->{RAW_MSG}, 6));
	debug "- $questID $mobID $count $goal\n", "info";
	if ($questID) {
		my $quest = \%{$questList->{$questID}};
		my $mission = \%{$quest->{missions}->{$mobID}};
		$mission->{goal} = $goal;
		$mission->{count} = $count;
		Plugins::callHook('quest_mission_updated', {
				questID => $questID,
				mobID => $mobID,
				count => $count,
				goal => $goal
		});
	}
}

# 02B7
sub quest_active {
	my ($self, $args) = @_;
	my $questID = $args->{questID};

	message $args->{active}
		? TF("Quest %s is now active.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
		: TF("Quest %s is now inactive.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
	, "info";

	$questList->{$args->{questID}}->{active} = $args->{active};
}

# 02C1
sub parse_npc_chat {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{ID});
}

sub npc_chat {
	my ($self, $args) = @_;

	# like public_chat, but also has color

	my $actor = $args->{actor};
	my $message = $args->{message}; # needs bytesToString or not?
	my $position = sprintf("[%s %d, %d]",
		$field ? $field->baseName : T("Unknown field,"),
		@{$char->{pos_to}}{qw(x y)});
	my $dist;

	if ($message =~ / : /) {
		((my $name), $message) = split / : /, $message, 2;
		$dist = 'unknown';
		unless ($actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}
		if ($actor->{name} eq $name) {
			$name = "$actor";
		} else {
			$name = sprintf "%s (%s)", $name, $actor->{binID};
		}
		$message = "$name: $message";

		$position .= sprintf(" [%d, %d] [dist=%s] (%d)",
			@{$actor->{pos_to}}{qw(x y)},
			$dist, $actor->{nameID});
		$dist = "[dist=$dist] ";
	}

	chatLog("npc", "$position $message\n") if ($config{logChat});
	message TF("%s%s\n", $dist, $message), "npcchat";

	# TODO hook
}

# 018d <packet len>.W { <name id>.W { <material id>.W }*3 }*
sub makable_item_list {
	my ($self, $args) = @_;
	undef $makableList;
	my $k = 0;
	my $msg;
	$msg .= center(" " . T("Create Item List") . " ", 79, '-') . "\n";
	for (my $i = 0; $i < length($args->{item_list}); $i += 8) {
		my $nameID = unpack("v", substr($args->{item_list}, $i, 2));
		$makableList->[$k] = $nameID;
		$msg .= swrite(sprintf("\@%s \@%s (\@%s)", ('>'x2), ('<'x50), ('<'x6)), [$k, itemNameSimple($nameID), $nameID]);
		$k++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
	message T("You can now use the 'create' command.\n"), "info";

	Plugins::callHook('makable_item_list', {
		item_list => $makableList,
	});
}

sub storage_opened {
	my ($self, $args) = @_;
	$char->storage->open($args);
}

sub storage_closed {
	$char->storage->close();
	message T("Storage closed.\n"), "storage";;

	# Storage log
	writeStorageLog(0);

	if ($char->{dcOnEmptyItems} ne "") {
		message TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems});
		chatLog("k", TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems}));
		quit();
	}
}

sub storage_items_stackable {
	my ($self, $args) = @_;

	$char->storage->clear;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Stackable Storage Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->storage->getByID($_[0]{ID}) },
		adder => sub { $char->storage->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			$local_item->{amount} = $local_item->{amount} & ~0x80000000;
		},
	});

	$storageTitle = $args->{title} ? $args->{title} : undef;
}

sub storage_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Non-Stackable Storage Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $char->storage->getByID($_[0]{ID}) },
		adder => sub { $char->storage->add($_[0]) },
	});

	$storageTitle = $args->{title} ? $args->{title} : undef;
}

sub storage_item_added {
	my ($self, $args) = @_;

	my $index = $args->{ID};
	my $amount = $args->{amount};

	my $item = $char->storage->getByID($index);
	if (!$item) {
		$item = new Actor::Item();
		$item->{nameID} = $args->{nameID};
		$item->{ID} = $index;
		$item->{amount} = $amount;
		$item->{type} = $args->{type};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{name} = itemName($item);
		$char->storage->add($item);
	} else {
		$item->{amount} += $amount;
	}
	my $disp = TF("Storage Item Added: %s (%d) x %d - %s",
			$item->{name}, $item->{binID}, $amount, $itemTypes_lut{$item->{type}});
	message "$disp\n", "drop";
	
	$itemChange{$item->{name}} += $amount;
	$args->{item} = $item;
}

sub storage_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(ID amount)};

	my $item = $char->storage->getByID($index);
	
	if ($item) {
		Misc::storageItemRemoved($item->{binID}, $amount);
	}
}

sub cart_items_stackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Stackable Cart Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->cart->getByID($_[0]{ID}) },
		adder => sub { $char->cart->add($_[0]) },
	});
}

sub cart_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Non-Stackable Cart Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $char->cart->getByID($_[0]{ID}) },
		adder => sub { $char->cart->add($_[0]) },
	});
}

sub cart_item_added {
	my ($self, $args) = @_;
	
	my $index = $args->{ID};
	my $amount = $args->{amount};

	my $item = $char->cart->getByID($index);
	if (!$item) {
		$item = new Actor::Item();
		$item->{ID} = $args->{ID};
		$item->{nameID} = $args->{nameID};
		$item->{amount} = $args->{amount};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{type} = $args->{type} if (exists $args->{type});
		$item->{name} = itemName($item);
		$char->cart->add($item);
	} else {
		$item->{amount} += $args->{amount};
	}
	my $disp = TF("Cart Item Added: %s (%d) x %d - %s",
			$item->{name}, $item->{binID}, $amount, $itemTypes_lut{$item->{type}});
	message "$disp\n", "drop";
	$itemChange{$item->{name}} += $args->{amount};
	$args->{item} = $item;
}

sub cart_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(ID amount)};

	my $item = $char->cart->getByID($index);
	
	if ($item) {
		Misc::cartItemRemoved($item->{binID}, $amount);
	}
}

sub cart_info {
	my ($self, $args) = @_;
	$char->cart->info($args);
	debug "[cart_info] received.\n", "parseMsg";
}

sub cart_add_failed {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 0) {
		$reason = T('overweight');
	} elsif ($args->{fail} == 1) {
		$reason = T('too many items');
	} else {
		$reason = TF("Unknown code %s",$args->{fail});
	}
	error TF("Can't Add Cart Item (%s)\n", $reason);
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_inventory',
		debug_str => 'Stackable Inventory Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->inventory->getByID($_[0]{ID}) },
		adder => sub { $char->inventory->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			if (defined $char->{arrow} && $local_item->{ID} eq $char->{arrow}) {
				$local_item->{equipped} = 32768;
				$char->{equipment}{arrow} = $local_item;
			}
		}
	});
}

sub login_error {
	my ($self, $args) = @_;

	$net->serverDisconnect();
	if ($args->{type} == REFUSE_INVALID_ID) {
		error TF("Account name [%s] doesn't exist\n", $config{'username'}), "connection";
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $username = $interface->query(T("Enter your Ragnarok Online username again."));
			if (defined($username)) {
				configModify('username', $username, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == REFUSE_INVALID_PASSWD) {
		error TF("Password Error for account [%s]\n", $config{'username'}), "connection";
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $password = $interface->query(T("Enter your Ragnarok Online password again."), isPassword => 1);
			if (defined($password)) {
				configModify('password', $password, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == ACCEPT_ID_PASSWD) {
		error T("The server has denied your connection.\n"), "connection";
	} elsif ($args->{type} == REFUSE_NOT_CONFIRMED) {
		$interface->errorDialog(T("Critical Error: Your account has been blocked."));
		$quit = 1 unless ($net->clientAlive());
	} elsif ($args->{type} == REFUSE_INVALID_VERSION) {
		my $master = $masterServer;
		error TF("Connect failed, something is wrong with the login settings:\n" .
			"version: %s\n" .
			"master_version: %s\n" .
			"serverType: %s\n", $master->{version}, $master->{master_version}, $masterServer->{serverType}), "connection";
		relog(30);
	} elsif ($args->{type} == REFUSE_BLOCK_TEMPORARY) {
		error TF("The server is temporarily blocking your connection until %s\n", $args->{date}), "connection";
	} elsif ($args->{type} == REFUSE_USER_PHONE_BLOCK) { #Phone lock
		error T("Please dial to activate the login procedure.\n"), "connection";
		Plugins::callHook('dial');
		relog(10);
	} elsif ($args->{type} == ACCEPT_LOGIN_USER_PHONE_BLOCK) {
		error T("Mobile Authentication: Max number of simultaneous IP addresses reached.\n"), "connection";
	} else {
		error TF("The server has denied your connection for unknown reason (%d).\n", $args->{type}), 'connection';
	}

	if ($args->{type} != REFUSE_INVALID_VERSION && $versionSearch) {
		$versionSearch = 0;
		writeSectionedFileIntact(Settings::getTableFilename("servers.txt"), \%masterServers);
	}
}

sub login_error_game_login_server {
	error T("Error logging into Character Server (invalid character specified)...\n"), 'connection';
	$net->setState(1);
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();
}

sub character_deletion_successful {
	if (defined $AI::temp::delIndex) {
		message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
		delete $chars[$AI::temp::delIndex];
		undef $AI::temp::delIndex;
		for (my $i = 0; $i < @chars; $i++) {
			delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
		}
	} else {
		message T("Character deleted.\n"), "info";
	}

	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_failed {
	error T("Character cannot be deleted. Your e-mail address was probably wrong.\n");
	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_moves {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	makeCoordsFromTo($char->{pos}, $char->{pos_to}, $args->{coords});
	my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * ($char->{walk_speed} || 0.12);

	# Correct the direction in which we're looking
	my (%vec, $degree);
	getVector(\%vec, $char->{pos_to}, $char->{pos});
	$degree = vectorToDegree(\%vec);
	if (defined $degree) {
		my $direction = int sprintf("%.0f", (360 - $degree) / 45);
		$char->{look}{body} = $direction & 0x07;
		$char->{look}{head} = 0;
	}

	# Ugly; AI code in network subsystem! This must be fixed.
	if (AI::action eq "mapRoute" && $config{route_escape_reachedNoPortal} && $dist eq "0.0"){
	   if (!$portalsID[0]) {
		if ($config{route_escape_shout} ne "" && !defined($timeout{ai_route_escape}{time})){
			sendMessage("c", $config{route_escape_shout});
		}
 	   	 $timeout{ai_route_escape}{time} = time;
	   	 AI::queue("escape");
	   }
	}
}

sub character_name {
	my ($self, $args) = @_;
	my $name; # Type: String

	$name = bytesToString($args->{name});
	debug "Character name received: $name\n";
}

sub character_status {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});

	if ($args->{switch} eq '028A') {
		$actor->{lv} = $args->{lv}; # TODO: test if it is ok to use this piece of information
		$actor->{opt3} = $args->{opt3};
	} elsif ($args->{switch} eq '0229' || $args->{switch} eq '0119') {
		$actor->{opt1} = $args->{opt1};
		$actor->{opt2} = $args->{opt2};
	}

	$actor->{option} = $args->{option};

	setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option});
}

sub chat_created {
	my ($self, $args) = @_;

	$currentChatRoom = $accountID;
	$chatRooms{$accountID} = {%createdChatRoom};
	binAdd(\@chatRoomsID, $accountID);
	binAdd(\@currentChatRoomUsers, $char->{name});
	message T("Chat Room Created\n");
	
	Plugins::callHook('chat_created', {
		chat => $chatRooms{$accountID},
	});
}

sub chat_info {
	my ($self, $args) = @_;

	my $title = bytesToString($args->{title});

	my $chat = $chatRooms{$args->{ID}};
	if (!$chat || !%{$chat}) {
		$chat = $chatRooms{$args->{ID}} = {};
		binAdd(\@chatRoomsID, $args->{ID});
	}
	$chat->{len} = $args->{len};
	$chat->{title} = $title;
	$chat->{ownerID} = $args->{ownerID};
	$chat->{limit} = $args->{limit};
	$chat->{public} = $args->{public};
	$chat->{num_users} = $args->{num_users};

	Plugins::callHook('packet_chatinfo', {
	  chatID => $args->{ID},
	  ownerID => $args->{ownerID},
	  title => $title,
	  limit => $args->{limit},
	  public => $args->{public},
	  num_users => $args->{num_users}
	});
}

sub chat_join_result {
	my ($self, $args) = @_;

	if ($args->{type} == 1) {
		message T("Can't join Chat Room - Incorrect Password\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're banned\n");
	}
}

sub chat_modified {
	my ($self, $args) = @_;

	my $title = bytesToString($args->{title});

	my ($ownerID, $chat_ID, $limit, $public, $num_users) = @{$args}{qw(ownerID ID limit public num_users)};
	my $ID;
	if ($ownerID eq $accountID) {
		$ID = $accountID;
	} else {
		$ID = $chat_ID;
	}
	
	my %chat = ();
	$chat{title} = $title;
	$chat{ownerID} = $ownerID;
	$chat{limit} = $limit;
	$chat{public} = $public;
	$chat{num_users} = $num_users;
	
	Plugins::callHook('chat_modified', {
		ID => $ID,
		old => $chatRooms{$ID},
		new => \%chat,
	});
	
	$chatRooms{$ID} = {%chat};
	
	message T("Chat Room Properties Modified\n");
}

sub chat_newowner {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($args->{type} == 0) {
		if ($user eq $char->{name}) {
			$chatRooms{$currentChatRoom}{ownerID} = $accountID;
		} else {
			my $player;
			for my $p (@$playersList) {
				if ($p->{name} eq $user) {
					$player = $p;
					last;
				}
			}

			if ($player) {
				my $key = $player->{ID};
				$chatRooms{$currentChatRoom}{ownerID} = $key;
			}
		}
		$chatRooms{$currentChatRoom}{users}{$user} = 2;
	} else {
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
	}
}

sub chat_user_join {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($currentChatRoom ne "") {
		binAdd(\@currentChatRoomUsers, $user);
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
		$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
		message TF("%s has joined the Chat Room\n", $user);
	}
}

sub chat_user_leave {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	delete $chatRooms{$currentChatRoom}{users}{$user};
	binRemove(\@currentChatRoomUsers, $user);
	$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
	if ($user eq $char->{name}) {
		binRemove(\@chatRoomsID, $currentChatRoom);
		delete $chatRooms{$currentChatRoom};
		undef @currentChatRoomUsers;
		$currentChatRoom = "";
		message T("You left the Chat Room\n");
		Plugins::callHook('chat_leave');
	} else {
		message TF("%s has left the Chat Room\n", $user);
	}
}

sub chat_removed {
	my ($self, $args) = @_;

	binRemove(\@chatRoomsID, $args->{ID});
	my $chat = delete $chatRooms{ $args->{ID} };
	
	Plugins::callHook('chat_removed', {
		ID => $args->{ID},
		chat => $chat,
	});
}

sub deal_add_other {
	my ($self, $args) = @_;

	if ($args->{nameID} > 0) {
		my $item = $currentDeal{other}{ $args->{nameID} } ||= {};
		$item->{amount} += $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{name} = itemName($item);
		message TF("%s added Item to Deal: %s x %s\n", $currentDeal{name}, $item->{name}, $args->{amount}), "deal";
	} elsif ($args->{amount} > 0) {
		$currentDeal{other_zeny} += $args->{amount};
		my $amount = formatNumber($args->{amount});
		message TF("%s added %s z to Deal\n", $currentDeal{name}, $amount), "deal";
	}
}

sub deal_begin {
	my ($self, $args) = @_;

	if ($args->{type} == 0) {
		error T("That person is too far from you to trade.\n"), "deal";
		Plugins::callHook("error_deal", { type =>$args->{type}} );
	} elsif ($args->{type} == 2) {
		error T("That person is in another deal.\n"), "deal";
		Plugins::callHook("error_deal", { type =>$args->{type}} );
	} elsif ($args->{type} == 3) {
		if (%incomingDeal) {
			$currentDeal{name} = $incomingDeal{name};
			undef %incomingDeal;
		} else {
			my $ID = $outgoingDeal{ID};
			my $player;
			$player = $playersList->getByID($ID) if (defined $ID);
			$currentDeal{ID} = $ID;
			if ($player) {
				$currentDeal{name} = $player->{name};
			} else {
				$currentDeal{name} = T('Unknown #') . unpack("V", $ID);
			}
			undef %outgoingDeal;
		}
		message TF("Engaged Deal with %s\n", $currentDeal{name}), "deal";
		Plugins::callHook("engaged_deal", {name => $currentDeal{name}});
	} elsif ($args->{type} == 5) {
		error T("That person is opening storage.\n"), "deal";
		Plugins::callHook("error_deal", { type =>$args->{type}} );
	} else {
		error TF("Deal request failed (unknown error %s).\n", $args->{type}), "deal";
		Plugins::callHook("error_deal", { type =>$args->{type}} );
	}
}

sub deal_cancelled {
	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	message T("Deal Cancelled\n"), "deal";
	Plugins::callHook("cancelled_deal");
}

sub deal_complete {
	undef %outgoingDeal;
	undef %incomingDeal;
	undef %currentDeal;
	message T("Deal Complete\n"), "deal";
	Plugins::callHook("complete_deal");
}

sub deal_finalize {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		$currentDeal{other_finalize} = 1;
		message TF("%s finalized the Deal\n", $currentDeal{name}), "deal";
		Plugins::callHook("finalized_deal", {name => $currentDeal{name}});

	} else {
		$currentDeal{you_finalize} = 1;
		# FIXME: shouldn't we do this when we actually complete the deal?
		$char->{zeny} -= $currentDeal{you_zeny};
		message T("You finalized the Deal\n"), "deal";
	}
}

sub deal_request {
	my ($self, $args) = @_;
	my $level = $args->{level} || 'Unknown'; # TODO: store this info
	my $user = bytesToString($args->{user});

	$incomingDeal{name} = $user;
	$timeout{ai_dealAutoCancel}{time} = time;
	message TF("%s (level %s) Requests a Deal\n", $user, $level), "deal";
	message T("Type 'deal' to start dealing, or 'deal no' to deny the deal.\n"), "deal";
	Plugins::callHook("incoming_deal", {name => $user});
}

sub devotion {
	my ($self, $args) = @_;
	my $msg = '';
	my $source = Actor::get($args->{sourceID});

	undef $devotionList->{$args->{sourceID}};
	for (my $i = 0; $i < 5; $i++) {
		my $ID = substr($args->{targetIDs}, $i*4, 4);
		last if unpack("V", $ID) == 0;
		$devotionList->{$args->{sourceID}}->{targetIDs}->{$ID} = $i;
		my $actor = Actor::get($ID);
		#FIXME: Need a better display
		$msg .= skillUseNoDamage_string($source, $actor, 0, 'devotion');
	}
	$devotionList->{$args->{sourceID}}->{range} = $args->{range};

	message "$msg", "devotion";
}

sub egg_list {
	my ($self, $args) = @_;
	my $msg = center(T(" Egg Hatch Candidates "), 38, '-') ."\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("a2", substr($args->{RAW_MSG}, $i, 2));
		my $item = $char->inventory->getByID($index);
		$msg .=  "$item->{binID} $item->{name}\n";
	}
	$msg .= ('-'x38) . "\n".
			T("Ready to use command 'pet [hatch|h] #'\n");
	message $msg, "list";
}

sub emoticon {
	my ($self, $args) = @_;
	my $emotion = $emotions_lut{$args->{type}}{display} || "<emotion #$args->{type}>";

	if ($args->{ID} eq $accountID) {
		message "$char->{name}: $emotion\n", "emotion";
		chatLog("e", "$char->{name}: $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

	} elsif (my $player = $playersList->getByID($args->{ID})) {
		my $name = $player->name;

		#my $dist = "unknown";
		my $dist = distance($char->{pos_to}, $player->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $name ($player->{binID}): $emotion\n"
		message TF("[dist=%s] %s (%d): %s\n", $dist, $name, $player->{binID}, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

		my $index = AI::findAction("follow");
		if ($index ne "") {
			my $masterID = AI::args($index)->{ID};
			if ($config{'followEmotion'} && $masterID eq $args->{ID} &&
			       distance($char->{pos_to}, $player->{pos_to}) <= $config{'followEmotion_distance'})
			{
				my %args = ();
				$args{timeout} = time + rand (1) + 0.75;

				if ($args->{type} == 30) {
					$args{emotion} = 31;
				} elsif ($args->{type} == 31) {
					$args{emotion} = 30;
				} else {
					$args{emotion} = $args->{type};
				}

				AI::queue("sendEmotion", \%args);
			}
		}
	} elsif (my $monster = $monstersList->getByID($args->{ID}) || $slavesList->getByID($args->{ID})) {
		my $dist = distance($char->{pos_to}, $monster->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $monster->name ($monster->{binID}): $emotion\n"
		message TF("[dist=%s] %s %s (%d): %s\n", $dist, $monster->{actorType}, $monster->name, $monster->{binID}, $emotion), "emotion";

	} else {
		my $actor = Actor::get($args->{ID});
		my $name = $actor->name;

		my $dist = T("unknown");
		if (!$actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}

		message TF("[dist=%s] %s: %s\n", $dist, $actor->nameIdx, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");
	}
	Plugins::callHook('packet_emotion', {
		emotion => $emotion,
		ID => $args->{ID}
	});
}

sub errors {
	my ($self, $args) = @_;

	Plugins::callHook('disconnected') if ($net->getState() == Network::IN_GAME);
	if ($net->getState() == Network::IN_GAME &&
		($config{dcOnDisconnect} > 1 ||
		($config{dcOnDisconnect} &&
		$args->{type} != 3 &&
		$args->{type} != 10))) {
		error T("Auto disconnecting on Disconnect!\n");
		chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
		$quit = 1;
	}

	$net->setState(1);
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	if (($args->{type} != 0)) {
		$net->serverDisconnect();
	}
	if ($args->{type} == 0) {
		# FIXME BAN_SERVER_SHUTDOWN is 0x1, 0x0 is BAN_UNFAIR
		if ($config{'dcOnServerShutDown'} == 1) {
			error T("Auto disconnecting on ServerShutDown!\n");
			chatLog("k", T("*** Server shutting down , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Server shutting down\n"), "connection";
		}
	} elsif ($args->{type} == 1) {
		if($config{'dcOnServerClose'} == 1) {
			error T("Auto disconnecting on ServerClose!\n");
			chatLog("k", T("*** Server is closed , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Error: Server is closed\n"), "connection";
		}
	} elsif ($args->{type} == 2) {
		if ($config{'dcOnDualLogin'} == 1) {
			error (TF("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
				"%s will now immediately 	disconnect.\n", $Settings::NAME));
			chatLog("k", T("*** DualLogin, auto disconnect! ***\n"));
			quit();
		} elsif ($config{'dcOnDualLogin'} >= 2) {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n");
			message TF("Reconnecting, wait %s seconds...\n", $config{'dcOnDualLogin'}), "connection";
			$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
		} else {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n"), "connection";
		}

	} elsif ($args->{type} == 3) {
		error T("Error: Out of sync with server\n"), "connection";
	} elsif ($args->{type} == 4) {
		# fRO: "Your account is not validated, please click on the validation link in your registration mail."
		error T("Error: Server is jammed due to over-population.\n"), "connection";
	} elsif ($args->{type} == 5) {
		error T("Error: You are underaged and cannot join this server.\n"), "connection";
	} elsif ($args->{type} == 6) {
		$interface->errorDialog(T("Critical Error: You must pay to play this account!\n"));
		$quit = 1 unless ($net->version == 1);
	} elsif ($args->{type} == 8) {
		error T("Error: The server still recognizes your last connection\n"), "connection";
	} elsif ($args->{type} == 9) {
		error T("Error: IP capacity of this Internet Cafe is full. Would you like to pay the personal base?\n"), "connection";
	} elsif ($args->{type} == 10) {
		error T("Error: You are out of available time paid for\n"), "connection";
	} elsif ($args->{type} == 15) {
		error T("Error: You have been forced to disconnect by a GM\n"), "connection";
	} elsif ($args->{type} == 101) {
		error T("Error: Your account has been suspended until the next maintenance period for possible use of 3rd party programs\n"), "connection";
	} elsif ($args->{type} == 102) {
		error T("Error: For an hour, more than 10 connections having same IP address, have made. Please check this matter.\n"), "connection";
	} else {
		error TF("Unknown error %s\n", $args->{type}), "connection";
	}
}

sub friend_logon {
	my ($self, $args) = @_;

	# Friend In/Out
	my $friendAccountID = $args->{friendAccountID};
	my $friendCharID = $args->{friendCharID};
	my $isNotOnline = $args->{isNotOnline};

	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			$friends{$i}{'online'} = 1 - $isNotOnline;
			if ($isNotOnline) {
				message TF("Friend %s has disconnected\n", $friends{$i}{name}), undef, 1;
			} else {
				message TF("Friend %s has connected\n", $friends{$i}{name}), undef, 1;
			}
			last;
		}
	}
}

sub friend_request {
	my ($self, $args) = @_;

	# Incoming friend request
	$incomingFriend{'accountID'} = $args->{accountID};
	$incomingFriend{'charID'} = $args->{charID};
	$incomingFriend{'name'} = bytesToString($args->{name});
	message TF("%s wants to be your friend\n", $incomingFriend{'name'});
	message TF("Type 'friend accept' to be friend with %s, otherwise type 'friend reject'\n", $incomingFriend{'name'});
}

sub friend_removed {
	my ($self, $args) = @_;

	# Friend removed
	my $friendAccountID =  $args->{friendAccountID};
	my $friendCharID =  $args->{friendCharID};
	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			message TF("%s is no longer your friend\n", $friends{$i}{'name'});
			binRemove(\@friendsID, $i);
			delete $friends{$i};
			last;
		}
	}
}

sub friend_response {
	my ($self, $args) = @_;

	# Response to friend request
	my $type = $args->{type};
	my $name = bytesToString($args->{name});
	if ($type) {
		message TF("%s rejected to be your friend\n", $name);
	} else {
		my $ID = @friendsID;
		binAdd(\@friendsID, $ID);
		$friends{$ID}{accountID} = substr($args->{RAW_MSG}, 4, 4);
		$friends{$ID}{charID} = substr($args->{RAW_MSG}, 8, 4);
		$friends{$ID}{name} = $name;
		$friends{$ID}{online} = 1;
		message TF("%s is now your friend\n", $name);
	}
}

sub homunculus_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("Fed homunculus with %s\n", itemNameSimple($args->{foodID})), "homunculus";
	} else {
		error TF("Failed to feed homunculus with %s: no food in inventory.\n", itemNameSimple($args->{foodID})), "homunculus";
		# auto-vaporize
		if ($char->{homunculus} && $char->{homunculus}{hunger} <= 11 && timeOut($char->{homunculus}{vaporize_time}, 5)) {
			$messageSender->sendSkillUse(244, 1, $accountID);
			$char->{homunculus}{vaporize_time} = time;
			error "Critical hunger level reached. Homunculus is put to rest.\n", "homunculus";
		}
	}
}

# TODO: wouldn't it be better if we calculated these only at (first) request after a change in value, if requested at all?
sub slave_calcproperty_handler {
	my ($slave, $args) = @_;
	# so we don't devide by 0
	# wtf
=pod
	$slave->{hp_max}       = ($args->{hp_max} > 0) ? $args->{hp_max} : $args->{hp};
	$slave->{sp_max}       = ($args->{sp_max} > 0) ? $args->{sp_max} : $args->{sp};
=cut

	$slave->{attack_speed}     = int (200 - (($args->{aspd} < 10) ? 10 : ($args->{aspd} / 10)));
	$slave->{hpPercent}    = $slave->{hp_max} ? ($slave->{hp} / $slave->{hp_max}) * 100 : undef;
	$slave->{spPercent}    = $slave->{sp_max} ? ($slave->{sp} / $slave->{sp_max}) * 100 : undef;
	$slave->{expPercent}   = ($args->{exp_max}) ? ($args->{exp} / $args->{exp_max}) * 100 : undef;
}

sub gameguard_grant {
	my ($self, $args) = @_;

	if ($args->{server} == 0) {
		error T("The server Denied the login because GameGuard packets where not replied " .
			"correctly or too many time has been spent to send the response.\n" .
			"Please verify the version of your poseidon server and try again\n"), "poseidon";
		return;
	} elsif ($args->{server} == 1) {
		message T("Server granted login request to account server\n"), "poseidon";
	} else {
		message T("Server granted login request to char/map server\n"), "poseidon";
		# FIXME
		change_to_constate25() if ($config{'gameGuard'} eq "2");
	}
	$net->setState(1.3) if ($net->getState() == 1.2);
}

sub guild_allies_enemy_list {
	my ($self, $args) = @_;

	# Guild Allies/Enemy List
	# <len>.w (<type>.l <guildID>.l <guild name>.24B).*
	# type=0 Ally
	# type=1 Enemy

	# This is the length of the entire packet
	my $msg = $args->{RAW_MSG};
	my $len = unpack("v", substr($msg, 2, 2));

	# clear $guild{enemy} and $guild{ally} otherwise bot will misremember alliances -zdivpsa
	$guild{enemy} = {}; $guild{ally} = {};

	for (my $i = 4; $i < $len; $i += 32) {
		my ($type, $guildID, $guildName) = unpack('V2 Z24', substr($msg, $i, 32));
		$guildName = bytesToString($guildName);
		if ($type) {
			# Enemy guild
			$guild{enemy}{$guildID} = $guildName;
		} else {
			# Allied guild
			$guild{ally}{$guildID} = $guildName;
		}
		debug "Your guild is ".($type ? 'enemy' : 'ally')." with guild $guildID ($guildName)\n", "guild";
	}
}

sub guild_ally_request {
	my ($self, $args) = @_;

	my $ID = $args->{ID}; # is this a guild ID or account ID? Freya calls it an account ID
	my $name = bytesToString($args->{guildName}); # Type: String

	message TF("Incoming Request to Ally Guild '%s'\n", $name);
	$incomingGuild{ID} = $ID;
	$incomingGuild{Type} = 2;
	$timeout{ai_guildAutoDeny}{time} = time;
}

sub guild_broken {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 2) {
		error T("Guild can not be undone: there are still members in the guild\n");
	} elsif ($flag == 1) {
		error T("Guild can not be undone: invalid key\n");
	} elsif ($flag == 0) {
		message T("Guild broken.\n");
		undef %{$char->{guild}};
		undef $char->{guildID};
		undef %guild;
	} else {
		error TF("Guild can not be undone: unknown reason (flag: %s)\n", $flag);
	}
}

sub guild_create_result {
	my ($self, $args) = @_;
	my $type = $args->{type};

	my %types = (
		0 => T("Guild create successful.\n"),
		2 => T("Guild create failed: Guild name already exists.\n"),
		3 => T("Guild create failed: Emperium is needed.\n")
	);
	if ($types{$type}) {
		message $types{$type};
	} else {
		message TF("Guild create: Unknown error %s\n", $type);
	}
}

sub guild_info {
	my ($self, $args) = @_;
	# Guild Info
	foreach (qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up name master castles_string)) {
		$guild{$_} = $args->{$_};
	}
	$guild{name} = bytesToString($args->{name});
	$guild{master} = bytesToString($args->{master});
	$guild{members}++; # count ourselves in the guild members count
}

sub guild_invite_result {
	my ($self, $args) = @_;

	my $type = $args->{type};

	my %types = (
		0 => T('Target is already in a guild.'),
		1 => T('Target has denied.'),
		2 => T('Target has accepted.'),
		3 => T('Your guild is full.')
	);
	if ($types{$type}) {
	    message TF("Guild join request: %s\n", $types{$type});
	} else {
	    message TF("Guild join request: Unknown %s\n", $type);
	}
}

sub guild_location {
	# FIXME: not implemented
	my ($self, $args) = @_;
	unless ($args->{x} > 0 && $args->{y} > 0) {
		# delete locator for ID
	} else {
		# add/replace locator for ID
	}
}

sub guild_leave {
	my ($self, $args) = @_;

	message TF("%s has left the guild.\n" .
		"Reason: %s\n", bytesToString($args->{name}), bytesToString($args->{message})), "schat";
}

sub guild_expulsion {
	my ($self, $args) = @_;

	message TF("%s has been removed from the guild.\n" .
		"Reason: %s\n", bytesToString($args->{name}), bytesToString($args->{message})), "schat";
}

sub guild_member_online_status {
	my ($self, $args) = @_;

	foreach my $guildmember (@{$guild{member}}) {
		if ($guildmember->{charID} eq $args->{charID}) {
			if ($guildmember->{online} = $args->{online}) {
				message TF("Guild member %s logged in.\n", $guildmember->{name}), "guildchat";
			} else {
				message TF("Guild member %s logged out.\n", $guildmember->{name}), "guildchat";
			}
			last;
		}
	}
}

sub misc_effect {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message sprintf(
		$actor->verb(T("%s use effect: %s\n"), T("%s uses effect: %s\n")),
		$actor, defined $effectName{$args->{effect}} ? $effectName{$args->{effect}} : T("Unknown #")."$args->{effect}"
	), 'effect'
}

sub guild_members_title_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i+=28) {
		$gtIndex = unpack('V', substr($msg, $i, 4));
		$guild{positions}[$gtIndex]{title} = bytesToString(unpack('Z24', substr($msg, $i + 4, 24)));
	}
}

sub guild_name {
	my ($self, $args) = @_;

	my $guildID = $args->{guildID};
	my $emblemID = $args->{emblemID};
	my $mode = $args->{mode};
	my $guildName = bytesToString($args->{guildName});
	$char->{guild}{name} = $guildName;
	$char->{guildID} = $guildID;
	$char->{guild}{emblem} = $emblemID;

	$messageSender->sendGuildMasterMemberCheck();
	$messageSender->sendGuildRequestInfo(0);	#requests for guild info packet 01B6 and 014C
	$messageSender->sendGuildRequestInfo(1);	#requests for guild member packet 0166 and 0154
	debug "guild name: $guildName\n";
}

sub guild_request {
	my ($self, $args) = @_;

	# Guild request
	my $ID = $args->{ID};
	my $name = bytesToString($args->{name});
	message TF("Incoming Request to join Guild '%s'\n", $name);
	$incomingGuild{'ID'} = $ID;
	$incomingGuild{'Type'} = 1;
	$timeout{'ai_guildAutoDeny'}{'time'} = time;
}

sub identify {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		my $item = $char->inventory->getByID($args->{ID});
		$item->{identified} = 1;
		$item->{type_equip} = $itemSlots_lut{$item->{nameID}};
		message TF("Item Identified: %s (%d)\n", $item->{name}, $item->{binID}), "info";
	} else {
		message T("Item Appraisal has failed.\n");
	}
	undef @identifyID;
}

# TODO: store this state
sub ignore_all_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("All Players ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("All players unignored\n");
		}
	}
}

# TODO: store list of ignored players
sub ignore_player_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("Player ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("Player unignored\n");
		}
	}
}

sub item_used {
	my ($self, $args) = @_;

	my ($index, $itemID, $ID, $remaining, $success) =
		@{$args}{qw(ID itemID actorID remaining success)};
	my %hook_args = (
		serverIndex => $index,
		itemID => $itemID,
		userID => $ID,
		remaining => $remaining,
		success => $success
	);

	if ($ID eq $accountID) {
		my $item = $char->inventory->getByID($index);
		if ($item) {
			if ($success == 1) {
				my $amount = $item->{amount} - $remaining;

				message TF("You used Item: %s (%d) x %d - %d left\n", $item->{name}, $item->{binID},
					$amount, $remaining), "useItem", 1;
				
				inventoryItemRemoved($item->{binID}, $amount);

				$hook_args{item} = $item;
				$hook_args{binID} = $item->{binID};
				$hook_args{name} => $item->{name};
				$hook_args{amount} = $amount;

			} else {
				message TF("You failed to use item: %s (%d)\n", $item ? $item->{name} : "#$itemID", $remaining), "useItem", 1;
			}
 		} else {
			if ($success == 1) {
				message TF("You used unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			} else {
				message TF("You failed to use unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			}
		}
	} else {
		my $actor = Actor::get($ID);
		my $itemDisplay = itemNameSimple($itemID);
		message TF("%s used Item: %s - %s left\n", $actor, $itemDisplay, $remaining), "useItem", 2;
	}
	Plugins::callHook('packet_useitem', \%hook_args);
}

sub married {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message TF("%s got married!\n", $actor);
}

sub item_appeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$item->{ID} = $args->{ID};
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	# Take item as fast as possible
	if (AI::state == AI::AUTO && pickupitems($item->{name}, $item->{nameID}) == 2
	 && ($config{'itemsTakeAuto'} || $config{'itemsGatherAuto'})
	 && (percent_weight($char) < $config{'itemsMaxWeight'})
	 && distance($item->{pos}, $char->{pos_to}) <= 5) {
		$messageSender->sendTake($args->{ID});
	}

	message TF("Item Appeared: %s (%d) x %d (%d, %d)\n", $item->{name}, $item->{binID}, $item->{amount}, $args->{x}, $args->{y}), "drop", 1;

}

sub item_exists {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{ID} = $args->{ID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	message TF("Item Exists: %s (%d) x %d\n", $item->{name}, $item->{binID}, $item->{amount}), "drop", 1;
}

sub item_disappeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	if ($item) {
		if ($config{attackLooters} && AI::action ne "sitAuto" && pickupitems($item->{name}, $item->{nameID}) > 0) {
			for my Actor::Monster $monster (@$monstersList) { # attack looter code
				if (my $control = mon_control($monster->name,$monster->{nameID})) {
					next if ( ($control->{attack_auto}  ne "" && $control->{attack_auto} == -1)
						|| ($control->{attack_lvl}  ne "" && $control->{attack_lvl} > $char->{lv})
						|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
						|| ($control->{attack_hp}   ne "" && $control->{attack_hp} > $char->{hp})
						|| ($control->{attack_sp}   ne "" && $control->{attack_sp} > $char->{sp})
						);
				}
				if (distance($item->{pos}, $monster->{pos}) == 0) {
					attack($monster->{ID});
					message TF("Attack Looter: %s looted %s\n", $monster->nameIdx, $item->{name}), "looter";
					last;
				}
			}
		}

		debug "Item Disappeared: $item->{name} ($item->{binID})\n", "parseMsg_presence";
		my $ID = $args->{ID};
		$items_old{$ID} = $item->deepCopy();
		$items_old{$ID}{disappeared} = 1;
		$items_old{$ID}{gone_time} = time;
		$itemsList->removeByID($ID);
	}
}

sub item_upgrade {
	my ($self, $args) = @_;
	my ($type, $index, $upgrade) = @{$args}{qw(type ID upgrade)};

	my $item = $char->inventory->getByID($index);
	if ($item) {
		$item->{upgrade} = $upgrade;
		message TF("Item %s has been upgraded to +%s\n", $item->{name}, $upgrade), "parseMsg/upgrade";
		$item->setName(itemName($item));
	}
}

sub job_equipment_hair_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	assert(UNIVERSAL::isa($actor, "Actor")) if DEBUG;

	if ($args->{part} == 0) {
		# Job change
		$actor->{jobID} = $args->{number};
 		message TF("%s changed job to: %s\n", $actor, $jobs_lut{$args->{number}}), "parseMsg/job", ($actor->isa('Actor::You') ? 0 : 2);

	} elsif ($args->{part} == 3) {
		# Bottom headgear change
 		message TF("%s changed bottom headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{low} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 4) {
		# Top headgear change
 		message TF("%s changed top headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{top} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 5) {
		# Middle headgear change
 		message TF("%s changed middle headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{mid} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 6) {
		# Hair color change
		$actor->{hair_color} = $args->{number};
 		message TF("%s changed hair color to: %s (%s)\n", $actor, $haircolors{$args->{number}}, $args->{number}), "parseMsg/hairColor", ($actor->isa('Actor::You') ? 0 : 2);
	}

	#my %parts = (
	#	0 => 'Body',
	#	2 => 'Right Hand',
	#	3 => 'Low Head',
	#	4 => 'Top Head',
	#	5 => 'Middle Head',
	#	8 => 'Left Hand'
	#);
	#if ($part == 3) {
	#	$part = 'low';
	#} elsif ($part == 4) {
	#	$part = 'top';
	#} elsif ($part == 5) {
	#	$part = 'mid';
	#}
	#
	#my $name = getActorName($ID);
	#if ($part == 3 || $part == 4 || $part == 5) {
	#	my $actor = Actor::get($ID);
	#	$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
	#	my $itemName = $items_lut{$itemID};
	#	$itemName = 'nothing' if (!$itemName);
	#	debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
	#} else {
	#	debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
	#}

}

# Leap, Snap, Back Slide... Various knockback
sub high_jump {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get ($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Unknown;
		$actor->{appear_time} = time;
		$actor->{nameID} = unpack ('V', $args->{ID});
	} elsif ($actor->{pos_to}{x} == $args->{x} && $actor->{pos_to}{y} == $args->{y}) {
		message TF("%s failed to instantly move\n", $actor->nameString), 'skill';
		return;
	}

	$actor->{pos} = {x => $args->{x}, y => $args->{y}};
	$actor->{pos_to} = {x => $args->{x}, y => $args->{y}};

	message TF("%s instantly moved to %d, %d\n", $actor->nameString, $actor->{pos_to}{x}, $actor->{pos_to}{y}), 'skill', 2;

	$actor->{time_move} = time;
	$actor->{time_move_calc} = 0;
}

sub hp_sp_changed {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $type = $args->{type};
	my $amount = $args->{amount};
	if ($type == 5) {
		$char->{hp} += $amount;
		$char->{hp} = $char->{hp_max} if ($char->{hp} > $char->{hp_max});
	} elsif ($type == 7) {
		$char->{sp} += $amount;
		$char->{sp} = $char->{sp_max} if ($char->{sp} > $char->{sp_max});
	}
}

# The difference between map_change and map_changed is that map_change
# represents a map change event on the current map server, while
# map_changed means that you've changed to a different map server.
# map_change also represents teleport events.
sub map_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	if ($ai_v{temp}{clear_aiQueue}) {
		AI::clear;
		AI::SlaveManager::clear();
	}

	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	if ($net->version == 0) {
		$ai_v{portalTrace_mapChanged} = time;
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};
	message TF("Map Change: %s (%s, %s)\n", $args->{map}, $char->{pos}{x}, $char->{pos}{y}), "connection";
	if ($net->version == 1) {
		ai_clientSuspend(0, 10);
	} else {
		$messageSender->sendMapLoaded();
		# $messageSender->sendSync(1);
		$timeout{ai}{time} = time;
	}

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});

	$timeout{ai}{time} = time;
}

# Parse 0A3B with structure
# '0A3B' => ['hat_effect', 'v a4 C a*', [qw(len ID flag effect)]],
# Unpack effect info into HatEFID
# @author [Cydh]
sub parse_hat_effect {
	my ($self, $args) = @_;
	@{$args->{effects}} = map {{ HatEFID => unpack('v', $_) }} unpack '(a2)*', $args->{effect};
	debug "Hat Effect. Flag: ".$args->{flag}." HatEFIDs: ".(join ', ', map {$_->{HatEFID}} @{$args->{effects}})."\n";
}

# Display information for player's Hat Effects
# @author [Cydh]
sub hat_effect {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	my $hatName;
	my $i = 0;

	#TODO: Stores the hat effect into actor for single player's information
	for my $hat (@{$args->{effects}}) {
		my $hatHandle;
		$hatName .= ", " if ($i);
		if (defined $hatEffectHandle{$hat->{HatEFID}}) {
			$hatHandle = $hatEffectHandle{$hat->{HatEFID}};
			$hatName .= defined $hatEffectName{$hatHandle} ? $hatEffectName{$hatHandle} : $hatHandle;
		} else {
			$hatName .= T("Unknown #").$hat->{HatEFID};
		}
		$i++;
	}

	if ($args->{flag} == 1) {
		message sprintf(
			$actor->verb(T("%s use effect: %s\n"), T("%s uses effect: %s\n")),
			$actor, $hatName
		), 'effect';
	} else {
		message sprintf(
			$actor->verb(T("%s are no longer: %s\n"), T("%s is no longer: %s\n")),
			$actor, $hatName
		), 'effect';
	}
}

sub npc_talk_close {
	my ($self, $args) = @_;
	# 00b6: long ID
	# "Close" icon appreared on the NPC message dialog
	my $ID = $args->{ID};
	my $name = getNPCName($ID);

	$ai_v{'npc_talk'}{'talk'} = 'close';
	$ai_v{'npc_talk'}{'time'} = time;
	undef %talk;

	Plugins::callHook('npc_talk_done', {ID => $ID});
}

sub npc_talk_continue {
	my ($self, $args) = @_;
	my $ID = substr($args->{RAW_MSG}, 2, 4);
	my $name = getNPCName($ID);

	$ai_v{'npc_talk'}{'talk'} = 'next';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_talk_number {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	$ai_v{'npc_talk'}{'talk'} = 'number';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_talk_responses {
	my ($self, $args) = @_;
	
	# 00b7: word len, long ID, string str
	# A list of selections appeared on the NPC message dialog.
	# Each item is divided with ':'
	my $msg = $args->{RAW_MSG};

	my $ID = substr($msg, 4, 4);
	my $nameID = unpack 'V', $ID;
	
	# Auto-create Task::TalkNPC if not active
	if (!AI::is("NPC") && !(AI::is("route") && $char->args->getSubtask && UNIVERSAL::isa($char->args->getSubtask, 'Task::TalkNPC'))) {
		debug "An unexpected npc conversation has started, auto-creating a TalkNPC Task\n";
		my $task = Task::TalkNPC->new(type => 'autotalk', nameID => $nameID, ID => $ID);
		AI::queue("NPC", $task);
		# TODO: The following npc_talk hook is only added on activation.
		# Make the task module or AI listen to the hook instead
		# and wrap up all the logic.
		$task->activate;
		Plugins::callHook('npc_autotalk', {
			task => $task
		});
	}
	
	$talk{ID} = $ID;
	$talk{nameID} = $nameID;
	my $talk = unpack("Z*", substr($msg, 8));
	$talk = substr($msg, 8) if (!defined $talk);
	$talk = bytesToString($talk);

	my @preTalkResponses = split /:/, $talk;
	$talk{responses} = [];
	foreach my $response (@preTalkResponses) {
		# Remove RO color codes
		$response =~ s/\^[a-fA-F0-9]{6}//g;
		if ($response =~ /^\^nItemID\^(\d+)$/) {
			$response = itemNameSimple($1);
		}

		push @{$talk{responses}}, $response if ($response ne "");
	}

	$talk{responses}[@{$talk{responses}}] = T("Cancel Chat");

	$ai_v{'npc_talk'}{'talk'} = 'select';
	$ai_v{'npc_talk'}{'time'} = time;

	Commands::run('talk resp');

	my $name = getNPCName($ID);
	Plugins::callHook('npc_talk_responses', {
						ID => $ID,
						name => $name,
						responses => $talk{responses},
						});
}

sub npc_talk_text {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	$ai_v{'npc_talk'}{'talk'} = 'text';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_store_begin {
	my ($self, $args) = @_;
	undef %talk;
	$talk{ID} = $args->{ID};
	$ai_v{'npc_talk'}{'talk'} = 'buy_or_sell';
	$ai_v{'npc_talk'}{'time'} = time;

	$storeList->{npcName} = getNPCName($args->{ID}) || T('Unknown');
}

sub npc_store_info {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $pack = 'V V C v';
	my $len = length pack $pack;
	$storeList->clear;
	undef %talk;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $len) {
		my $item = Actor::Item->new;
		@$item{qw( price _ type nameID )} = unpack $pack, substr $msg, $i, $len;
		$item->{ID} = $item->{nameID};
		$item->{name} = itemName($item);
		$storeList->add($item);

		debug "Item added to Store: $item->{name} - $item->{price}z\n", "parseMsg", 2;
	}

	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if (AI::action ne 'buyAuto') {
		Commands::run('store');
	}
}

sub deal_add_you {
	my ($self, $args) = @_;

	if ($args->{fail} == 1) {
		error T("That person is overweight; you cannot trade.\n"), "deal";
		return;
	} elsif ($args->{fail} == 2) {
		error T("This item cannot be traded.\n"), "deal";
		return;
	} elsif ($args->{fail}) {
		error TF("You cannot trade (fail code %s).\n", $args->{fail}), "deal";
		return;
	}

	my $id = unpack('v',$args->{ID});
	
	return unless ($id > 0);

	my $item = $char->inventory->getByID($args->{ID});
	$args->{item} = $item;
	# FIXME: quickly add two items => lastItemAmount is lost => inventory corruption; see also Misc::dealAddItem
	# FIXME: what will be in case of two items with the same nameID?
	# TODO: no info about items is stored
	$currentDeal{you_items}++;
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$currentDeal{you}{$item->{nameID}}{nameID} = $item->{nameID};
	message TF("You added Item to Deal: %s x %s\n", $item->{name}, $currentDeal{lastItemAmount}), "deal";
	inventoryItemRemoved($item->{binID}, $currentDeal{lastItemAmount});
}

sub skill_exchange_item {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("Change Material is ready. Use command 'cm' to continue.\n"), "info";
	} else {
		message T("Four Spirit Analysis is ready. Use command 'analysis' to continue.\n"), "info";
	}
	##
	# $args->{type} : Type
	#                 0: Change Material         -> 1
	#                 1: Elemental Analysis Lv 1 -> 2
	#                 2: Elemental Analysis Lv 2 -> 3
	#                 This value will be added +1 for simple check later
	# $args->{val} : ????
	##
	$skillExchangeItem = $args->{type} + 1;
}

# Allowed to RefineUI by server
# '0AA0' => ['refineui_opened', '' ,[qw()]],
# @author [Cydh]
sub refineui_opened {
	my ($self, $args) = @_;
	message TF("RefineUI is opened. Type 'i' to check equipment and its index. To continue: refineui select [ItemIdx]\n"), "info";
	$refineUI->{open} = 1;
}

# Received refine info for selected item
# '0AA2' => ['refineui_info', 'v v C a*' ,[qw(index bless materials)]],
# @param args Packet data
# @author [Cydh]
sub refineui_info {
	my ($self, $args) = @_;

	if ($args->{len} > 7) {
		$refineUI->{itemIndex} = $args->{index};
		$refineUI->{bless} = $args->{bless};

		my $item = $char->inventory->[$refineUI->{invIndex}];
		my $bless = $char->inventory->getByNameID($Blacksmith_Blessing);

		message T("========= RefineUI Info =========\n"), "info";
		message TF("Target Equip:\n".
				"- Index: %d\n".
				"- Name: %s\n",
				$refineUI->{invIndex}, $item ? itemName($item) : "Unknown."),
				"info";

		message TF("%s:\n".
				"- Needed: %d\n".
				"- Owned: %d\n",
				#itemNameSimple($Blacksmith_Blessing)
				"Blacksmith Blessing", $refineUI->{bless}, $bless ? $bless->{amount} : 0),
				"info";

		@{$refineUI->{materials}} = map { my %r; @r{qw(nameid chance zeny)} = unpack 'v C V', $_; \%r} unpack '(a7)*', $args->{materials};

		my $msg = center(T(" Possible Materials "), 53, '-') ."\n" .
				T("Mat_ID      %           Zeny        Material                        \n");
		foreach my $mat (@{$refineUI->{materials}}) {
			my $myMat = $char->inventory->getByNameID($mat->{nameid});
			my $myMatCount = sprintf("%d ea %s", $myMat ? $myMat->{amount} : 0, itemNameSimple($mat->{nameid}));
			$msg .= swrite(
				"@>>>>>>>> @>>>>> @>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$mat->{nameid}, $mat->{chance}, $mat->{zeny}, $myMatCount]);
		}
		$msg .= ('-'x53) . "\n";
		message $msg, "info";
		message TF("Continue: refineui refine %d [Mat_ID] [catalyst_toggle] to continue.\n", $refineUI->{invIndex}), "info";
	} else {
		error T("Equip cannot be refined, try different equipment. Type 'i' to check equipment and its index.\n");
	}
}

sub character_ban_list {
	my ($self, $args) = @_;
	# Header + Len + CharList[character_name(size:24)]
}

sub flag {
	my ($self, $args) = @_;
}

sub parse_stat_info {
	my ($self, $args) = @_;
	if($args->{switch} eq "0ACB") {
		$args->{val} = getHex($args->{val});
		$args->{val} = join '', reverse split / /, $args->{val};
		$args->{val} = hex $args->{val};
	}
}

sub parse_exp {
	my ($self, $args) = @_;
	if($args->{switch} eq "0ACC") {
		$args->{val} = getHex($args->{val});
		$args->{val} = join '', reverse split / /, $args->{val};
		$args->{val} = hex $args->{val};
	}
}

sub clone_vender_found {
	my ($self, $args) = @_;
	my $ID = unpack("V", $args->{ID});
	if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
		binAdd(\@venderListsID, $ID);
		Plugins::callHook('packet_vender', {ID => $ID, title => bytesToString($args->{title})});
	}
	$venderLists{$ID}{title} = bytesToString($args->{title});
	$venderLists{$ID}{id} = $ID;

	my $actor = $playersList->getByID($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Player();
		$actor->{ID} = $args->{ID};
		$actor->{nameID} = $ID;
		$actor->{appear_time} = time;
		$actor->{jobID} = $args->{jobID};
		$actor->{pos_to}{x} = $args->{coord_x};
		$actor->{pos_to}{y} = $args->{coord_y};
		$actor->{walk_speed} = 1; #hack
		$actor->{robe} = $args->{robe};
		$actor->{clothes_color} = $args->{clothes_color};
		$actor->{headgear}{low} = $args->{lowhead};
		$actor->{headgear}{mid} = $args->{midhead};
		$actor->{headgear}{top} = $args->{tophead};
		$actor->{weapon} = $args->{weapon};
		$actor->{shield} = $args->{shield};
		$actor->{sex} = $args->{sex};
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

		$playersList->add($actor);
		Plugins::callHook('add_player_list', $actor);
	}
}

sub clone_vender_lost {
	my ($self, $args) = @_;

	my $ID = unpack("V", $args->{ID});
	binRemove(\@venderListsID, $ID);
	delete $venderLists{$ID};

	if (defined $playersList->getByID($args->{ID})) {
		my $player = $playersList->getByID($args->{ID});

		if (grep { $ID eq $_ } @venderListsID) {
			binRemove(\@venderListsID, $ID);
			delete $venderLists{$ID};
		}

		$player->{gone_time} = time;
		$players_old{$ID} = $player->deepCopy();
		Plugins::callHook('player_disappeared', {player => $player});

		$playersList->removeByID($args->{ID});
	}
}

sub remain_time_info {
	my ($self, $args) = @_;
	debug TF("Remain Time - Result: %s - Expiration Date: %s - Time: %s\n", $args->{result}, $args->{expiration_date}, $args->{remain_time}), "console", 1;
}

sub received_login_token {
	my ($self, $args) = @_;

	my $master = $masterServers{$config{master}};

	$messageSender->sendTokenToServer($config{username}, $config{password}, $master->{master_version}, $master->{version}, $args->{login_token}, $args->{len}, $master->{OTT_ip}, $master->{OTT_port});
}


# this info will be sent to xkore 2 clients
sub hotkeys {
	my ($self, $args) = @_;
	undef $hotkeyList;
	my $msg;

	# TODO: implement this: $hotkeyList->{rotate} = $args->{rotate} if $args->{rotate};
	$msg .= center(" " . T("Hotkeys") . " ", 79, '-') . "\n";
	$msg .=	swrite(sprintf("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			["#", T("Name"), T("Type"), T("Lv")]);
	$msg .= sprintf("%s\n", ('-'x79));
	my $j = 0;
	for (my $i = 0; $i < length($args->{hotkeys}); $i += 7) {
		@{$hotkeyList->[$j]}{qw(type ID lv)} = unpack('C V v', substr($args->{hotkeys}, $i, 7));
		$msg .= swrite(TF("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			[$j, $hotkeyList->[$j]->{type} ? Skill->new(idn => $hotkeyList->[$j]->{ID})->getName() : itemNameSimple($hotkeyList->[$j]->{ID}),
			$hotkeyList->[$j]->{type} ? T("skill") : T("item"),
			$hotkeyList->[$j]->{lv}]);
		$j++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	debug($msg, "list");
}

sub received_character_ID_and_Map {
	my ($self, $args) = @_;
	message T("Received character ID and Map IP from Character Server\n"), "connection";
	$net->setState(4);
	undef $conState_tries;
	$charID = $args->{charID};

	if ($net->version == 1) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	my ($map) = $args->{mapName} =~ /([\s\S]*)\./; # cut off .gat
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	if($args->{'mapUrl'} =~ /.*\:\d+/) {
		$map_ip = $args->{mapUrl};
		$map_ip =~ s/:[0-9]+//;
		$map_port = $args->{mapPort};
	} else {
		$map_ip = makeIP($args->{mapIP});
		$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$map_port = $args->{mapPort};
	}

	message TF("----------Game Info----------\n" .
		"Char ID: %s (%s)\n" .
		"MAP Name: %s\n" .
		"MAP IP: %s\n" .
		"MAP Port: %s\n" .
		"-----------------------------\n", getHex($charID), unpack("V1", $charID),
		$args->{mapName}, $map_ip, $map_port), "connection";
	checkAllowedMap($map_noinstance);
	message(T("Closing connection to Character Server\n"), "connection") unless ($net->version == 1);
	$net->serverDisconnect(1);
	main::initStatVars();
}

sub received_sync {
	return unless changeToInGameState();
	debug "Received Sync\n", 'parseMsg', 2;
	$timeout{'play'}{'time'} = time;
}

sub actor_look_at {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	$actor->{look}{head} = $args->{head};
	$actor->{look}{body} = $args->{body};
	debug $actor->nameString . " looks at $args->{body}, $args->{head}\n", "parseMsg";
}

sub actor_movement_interrupted {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my %coords;
	$coords{x} = $args->{x};
	$coords{y} = $args->{y};

	my $actor = Actor::get($args->{ID});
	$actor->{pos} = {%coords};
	$actor->{pos_to} = {%coords};
	if ($actor->isa('Actor::You') || $actor->isa('Actor::Player')) {
		$actor->{sitting} = 0;
	}
	if ($actor->isa('Actor::You')) {
		debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
		AI::clear("move");
	}
	if ($char->{homunculus} && $char->{homunculus}{ID} eq $actor->{ID}) {
		AI::clear("move");
	}
}

sub actor_trapped {
	my ($self, $args) = @_;
	# original comment was that ID is not a valid ID
	# but it seems to be, at least on eAthena/Freya
	my $actor = Actor::get($args->{ID});
	debug "$actor->nameString() is trapped.\n";
}

sub party_join {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $keys;
	my $info;
	if ($args->{switch} eq '0104') {  # DEFAULT OLD PACKET
		$keys = [qw(ID role x y type name user map)];
	} elsif ($args->{switch} eq '01E9') { # PACKETVER >= 2015
		$keys = [qw(ID role x y type name user map lv item_pickup item_share)];

	} elsif ($args->{switch} eq '0A43') { #  PACKETVER >= 2016
		$keys = [qw(ID role jobID lv x y type name user map item_pickup item_share)];

	} elsif ($args->{switch} eq '0AE4') { #  PACKETVER >= 2017
		$keys = [qw(ID charID role jobID lv x y type name user map item_pickup item_share)];

	} else { # this can't happen
		return;
	}
	
	@{$info}{@{$keys}} = @{$args}{@{$keys}};

	if (!$char->{party}{joined} || !$char->{party}{users}{$info->{ID}} || !%{$char->{party}{users}{$info->{ID}}}) {
		binAdd(\@partyUsersID, $info->{ID}) if (binFind(\@partyUsersID, $info->{ID}) eq "");
		if ($info->{ID} eq $accountID) {
			message TF("You joined party '%s'\n", $info->{name}), undef, 1;
			# Some servers receive party_users_info before party_join when logging in
			# This is to prevent clearing info already in $char->{party}
			$char->{party} = {} unless ref($char->{party}) eq "HASH";
			$char->{party}{joined} = 1;
			Plugins::callHook('packet_partyJoin', { partyName => $info->{name} });
		} else {
			message TF("%s joined your party '%s'\n", $info->{user}, $info->{name}), undef, 1;
		}
	}

	my $actor = $char->{party}{users}{$info->{ID}} && %{$char->{party}{users}{$info->{ID}}} ? $char->{party}{users}{$info->{ID}} : new Actor::Party;

	$actor->{admin} = !$info->{'role'};
	delete $actor->{statuses} unless $actor->{'online'} = !$info->{'type'};
	$actor->{pos}{x} = $info->{'x'};
	$actor->{pos}{y} = $info->{'y'};
	$actor->{map} = $info->{'map'};
	$actor->{name} = $info->{'user'};
	$actor->{ID} = $info->{'ID'};
	$actor->{lv} = $info->{'lv'} if $info->{'lv'};
	$actor->{jobID} = $info->{'jobID'} if $info->{'jobID'};
	$actor->{charID} = $info->{'charID'} if $info->{'charID'}; # why now use charID?
	$char->{party}{users}{$info->{'ID'}} = $actor;
	$char->{party}{name} = $info->{'name'};
	$char->{party}{itemPickup} = $info->{'item_pickup'};
	$char->{party}{itemDivision} = $info->{'item_share'};
}

# TODO: store this state
sub party_allow_invite {
   my ($self, $args) = @_;

   if ($args->{type}) {
      message T("Not allowed other player invite to Party\n"), "party", 1;
   } else {
      message T("Allowed other player invite to Party\n"), "party", 1;
   }
}

sub party_chat {
	my ($self, $args) = @_;
	my $msg = bytesToString($args->{message});

	# Type: String
	my ($chatMsgUser, $chatMsg) = $msg =~ /(.*?) : (.*)/;
	$chatMsgUser =~ s/ $//;

	stripLanguageCode(\$chatMsg);
	# Type: String
	my $chat = "$chatMsgUser : $chatMsg";
	message TF("[Party] %s\n", $chat), "partychat";

	chatLog("p", "$chat\n") if ($config{'logPartyChat'});
	ChatQueue::add('p', $args->{ID}, $chatMsgUser, $chatMsg);

	Plugins::callHook('packet_partyMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});
}

sub party_exp {
	my ($self, $args) = @_;
	$char->{party}{share} = $args->{type}; # Always will be there, in 0101 also in 07D8
	if ($args->{type} == 0) {
		message T("Party EXP set to Individual Take\n"), "party", 1;
	} elsif ($args->{type} == 1) {
		message T("Party EXP set to Even Share\n"), "party", 1;
	} else {
		error T("Error setting party option\n");
	}
	if(exists($args->{itemPickup}) || exists($args->{itemDivision})) {
		$char->{party}{itemPickup} = $args->{itemPickup};
		$char->{party}{itemDivision} = $args->{itemDivision};
		if ($args->{itemPickup} == 0) {
			message T("Party item set to Individual Take\n"), "party", 1;
		} elsif ($args->{itemPickup} == 1) {
			message T("Party item set to Even Share\n"), "party", 1;
		} else {
			error T("Error setting party option\n");
		}
		if ($args->{itemDivision} == 0) {
			message T("Party item division set to Individual Take\n"), "party", 1;
		} elsif ($args->{itemDivision} == 1) {
			message T("Party item division set to Even Share\n"), "party", 1;
		} else {
			error T("Error setting party option\n");
		}
	}
}

sub party_leader {
	my ($self, $args) = @_;
	for (my $i = 0; $i < @partyUsersID; $i++) {
		if (unpack("V",$partyUsersID[$i]) eq $args->{new}) {
			$char->{party}{users}{$partyUsersID[$i]}{admin} = 1;
			message TF("New party leader: %s\n", $char->{party}{users}{$partyUsersID[$i]}{name}), "party", 1;
		}
		if (unpack("V",$partyUsersID[$i]) eq $args->{old}) {
			$char->{party}{users}{$partyUsersID[$i]}{admin} = '';
		}
	}
}

sub party_hp_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{hp} = $args->{hp};
		$char->{party}{users}{$ID}{hp_max} = $args->{hp_max};
	}
}

sub party_invite {
	my ($self, $args) = @_;
	message TF("Incoming Request to join party '%s'\n", bytesToString($args->{name}));
	$incomingParty{ID} = $args->{ID};
	$incomingParty{ACK} = $args->{switch} eq '02C6' ? '02C7' : '00FF';
	$timeout{ai_partyAutoDeny}{time} = time;
}

sub party_invite_result {
	my ($self, $args) = @_;
	my $name = bytesToString($args->{name});
	if ($args->{type} == ANSWER_ALREADY_OTHERGROUPM) {
		warning TF("Join request failed: %s is already in a party\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_REFUSE) {
		warning TF("Join request failed: %s denied request\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_ACCEPT) {
		message TF("%s accepted your request\n", $name), "info";
	} elsif ($args->{type} == ANSWER_MEMBER_OVERSIZE) {
		message T("Join request failed: Party is full.\n"), "info";
	} elsif ($args->{type} == ANSWER_DUPLICATE) {
		message TF("Join request failed: same account of %s allready joined the party.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_JOINMSG_REFUSE) {
		message TF("Join request failed: ANSWER_JOINMSG_REFUSE.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_ERROR) {
		message TF("Join request failed: unknown error.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_CHARACTER) {
		message TF("Join request failed: the character is not currently online or does not exist.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_INVALID_MAPPROPERTY) {
		message TF("Join request failed: ANSWER_INVALID_MAPPROPERTY.\n", $name), "info";
	}
}

sub party_leave {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $actor = $char->{party}{users}{$ID}; # bytesToString($args->{name})
	delete $char->{party}{users}{$ID};
	binRemove(\@partyUsersID, $ID);
	if ($ID eq $accountID) {
		$actor = $char;
		delete $char->{party};
		undef @partyUsersID;
		$char->{party}{joined} = 0;
	}

	if ($args->{result} == GROUPMEMBER_DELETE_LEAVE) {
		message TF("%s left the party\n", $actor);
	} elsif ($args->{result} == GROUPMEMBER_DELETE_EXPEL) {
		message TF("%s left the party (kicked)\n", $actor);
	} else {
		message TF("%s left the party (unknown reason: %d)\n", $actor, $args->{result});
	}
}

sub party_location {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{pos}{x} = $args->{x};
		$char->{party}{users}{$ID}{pos}{y} = $args->{y};
		$char->{party}{users}{$ID}{online} = 1;
		debug "Party member location: $char->{party}{users}{$ID}{name} - $args->{x}, $args->{y}\n", "parseMsg";
	}
}
sub party_organize_result {
	my ($self, $args) = @_;

	unless ($args->{fail}) {
		$char->{party}{users}{$accountID}{admin} = 1 if $char->{party}{users}{$accountID};
	} elsif ($args->{fail} == 1) {
		warning T("Can't organize party - party name exists\n");
	} elsif ($args->{fail} == 2) {
		warning T("Can't organize party - you are already in a party\n");
	} elsif ($args->{fail} == 3) {
		warning T("Can't organize party - not allowed in current map\n");
	} else {
		warning TF("Can't organize party - unknown (%d)\n", $args->{fail});
	}
}

sub party_show_picker {
	my ($self, $args) = @_;

	# wtf the server sends this packet for your own character? (rRo)
	return if $args->{sourceID} eq $accountID;

	my $string = ($char->{party}{users}{$args->{sourceID}} && %{$char->{party}{users}{$args->{sourceID}}}) ? $char->{party}{users}{$args->{sourceID}}->name() : $args->{sourceID};
	my $item = {};
	$item->{nameID} = $args->{nameID};
	$item->{identified} = $args->{identified};
	$item->{upgrade} = $args->{upgrade};
	$item->{cards} = $args->{cards};
	$item->{broken} = $args->{broken};
	message TF("Party member %s has picked up item %s.\n", $string, itemName($item)), "info";
}

sub party_users_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $player_info;

	if ($args->{switch} eq '00FB') {  # DEFAULT OLD PACKET
		$player_info = {
			len => 46,
			types => 'V Z24 Z16 C2',
			keys => [qw(ID name map admin online)],
		};

	} elsif ($args->{switch} eq '0A44') { # PACKETVER >= 20151007
		$player_info = {
			len => 50,
			types => 'V Z24 Z16 C2 v2',
			keys => [qw(ID name map admin online jobID lv)],
		};

	} elsif ($args->{switch} eq '0AE5') { #  PACKETVER >= 20171207
		$player_info = {
			len => 54,
			types => 'V V Z24 Z16 C2 v2',
			keys => [qw(ID GID name map admin online jobID lv)],
		};

	} else { # this can't happen
		return;
	}

	$char->{party}{name} = bytesToString($args->{party_name});

	for (my $i = 0; $i < length($args->{playerInfo}); $i += $player_info->{len}) {
		# in 0a43 lasts bytes: { <item pickup rule>.B <item share rule>.B <unknown>.L }
		return if(length($args->{playerInfo}) - $i == 6);

		my $ID = substr($args->{playerInfo}, $i, 4);

		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}

		$char->{party}{users}{$ID} = new Actor::Party();
		@{$char->{party}{users}{$ID}}{@{$player_info->{keys}}} = unpack($player_info->{types}, substr($args->{playerInfo}, $i, $player_info->{len}));
		$char->{party}{users}{$ID}{name} = bytesToString($char->{party}{users}{$ID}{name});
		$char->{party}{users}{$ID}{admin} = !$char->{party}{users}{$ID}{admin};
		$char->{party}{users}{$ID}{online} = !$char->{party}{users}{$ID}{online};

		debug TF("Party Member: %s (%s)\n", $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map}), "party", 1;
	}
}

sub rodex_mail_list {
	my ( $self, $args ) = @_;
	
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $header_pack = 'v C C C';
	my $header_len = ((length pack $header_pack) + 2);
	
	my $mail_pack = 'V2 C C Z24 V V v';
	my $base_mail_len = length pack $mail_pack;
	
	if ($args->{switch} eq '0A7D') {
		$rodexList->{current_page} = 0;
		$rodexList = {};
		$rodexList->{mails} = {};
	} else {
		$rodexList->{current_page}++;
	}
	
	if ($args->{isEnd} == 1) {
		$rodexList->{last_page} = $rodexList->{current_page};
	} else {
		$rodexList->{mails_per_page} = $args->{amount};
	}
	
	my $mail_len;
	
	my $print_msg = center(" " . "Rodex Mail Page ". $rodexList->{current_page} . " ", 79, '-') . "\n";
	
	my $index = 0;
	for (my $i = $header_len; $i < $args->{RAW_MSG_SIZE}; $i+=$mail_len) {
		my $mail;

		($mail->{mailID1},
		$mail->{mailID2},
		$mail->{isRead},
		$mail->{type},
		$mail->{sender},
		$mail->{regDateTime},
		$mail->{expireDateTime},
		$mail->{Titlelength}) = unpack($mail_pack, substr($msg, $i, $base_mail_len));
		
		$mail->{title} = substr($msg, ($i+$base_mail_len), $mail->{Titlelength});
		
		$mail->{page} = $rodexList->{current_page};
		$mail->{page_index} = $index;
		
		$mail_len = $base_mail_len + $mail->{Titlelength};
		
		$rodexList->{mails}{$mail->{mailID1}} = $mail;
		
		$rodexList->{current_page_last_mailID} = $mail->{mailID1};
		
		$print_msg .= swrite("@<<< @<<<<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<< @<<< @<<<<<<<< @<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<", [$index, "From:", $mail->{sender}, "Read:", $mail->{isRead} ? "Yes" : "No", "ID:", $mail->{mailID1}, "Title:", $mail->{title}]);
		
		$index++;
	}
	$print_msg .= sprintf("%s\n", ('-'x79));
	message $print_msg, "list";
}

sub rodex_read_mail {
	my ( $self, $args ) = @_;
	
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $header_pack = 'v C V2 v V2 C';
	my $header_len = ((length pack $header_pack) + 2);
	
	my $mail = {};
	
	$mail->{body} = substr($msg, $header_len, $args->{text_len});
	$mail->{zeny1} = $args->{zeny1};
	$mail->{zeny2} = $args->{zeny2};
	
	my $item_pack = 'v2 C3 a8 a4 C a4 a25';
	my $item_len = length pack $item_pack;
	
	my $mail_len;
	
	$mail->{items} = [];
	
	my $print_msg = center(" " . "Mail ".$args->{mailID1} . " ", 79, '-') . "\n";
	
	my @message_parts = unpack("(A51)*", $mail->{body});
	
	$print_msg .= swrite("@<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", ["Message:", $message_parts[0]]);
	
	foreach my $part (@message_parts[1..$#message_parts]) {
		$print_msg .= swrite("@<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", ["", $part]);
	}
	
	$print_msg .= swrite("@<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", ["Item count:", $args->{itemCount}]);
	
	$print_msg .= swrite("@<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", ["Zeny:", $args->{zeny1}]);

	my $index = 0;
	for (my $i = ($header_len + $args->{text_len}); $i < $args->{RAW_MSG_SIZE}; $i += $item_len) {
		my $item;
		($item->{amount},
		$item->{nameID},
		$item->{identified},
		$item->{broken},
		$item->{upgrade},
		$item->{cards},
		$item->{unknow1},
		$item->{type},
		$item->{unknow2},
		$item->{options}) = unpack($item_pack, substr($msg, $i, $item_len));
		
		$item->{name} = itemName($item);
		
		my $display = $item->{name};
		$display .= " x $item->{amount}";
		
		$print_msg .= swrite("@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [$index, $display]);
		
		push(@{$mail->{items}}, $item);
		$index++;
	}
	
	$print_msg .= sprintf("%s\n", ('-'x79));
	message $print_msg, "list";
	
	@{$rodexList->{mails}{$args->{mailID1}}}{qw(body items zeny1 zeny2)} = @{$mail}{qw(body items zeny1 zeny2)};
	
	$rodexList->{mails}{$args->{mailID1}}{isRead} = 1;
	
	$rodexList->{current_read} = $args->{mailID1};
}

sub unread_rodex {
	my ( $self, $args ) = @_;
	message "You have new unread rodex mails.\n";
}

sub rodex_remove_item {
	my ( $self, $args ) = @_;
	
	if (!$args->{result}) {
		error "You failed to remove an item from rodex mail.\n";
		return;
	}
	
	my $rodex_item = $rodexWrite->{items}->getByID($args->{ID});
	
	my $disp = TF("Item removed from rodex mail message: %s (%d) x %d - %s",
			$rodex_item->{name}, $rodex_item->{binID}, $args->{amount}, $itemTypes_lut{$rodex_item->{type}});
	message "$disp\n", "drop";
	
	$rodex_item->{amount} -= $args->{amount};
	if ($rodex_item->{amount} <= 0) {
		$rodexWrite->{items}->remove($rodex_item);
	}
}

sub rodex_add_item {
	my ( $self, $args ) = @_;
	
	if ($args->{fail}) {
		error "You failed to add an item to rodex mail.\n";
		return;
	}
	
	my $rodex_item = $rodexWrite->{items}->getByID($args->{ID});
	
	if ($rodex_item) {
		$rodex_item->{amount} += $args->{amount};
	} else {
		$rodex_item = new Actor::Item();
		$rodex_item->{ID} = $args->{ID};
		$rodex_item->{nameID} = $args->{nameID};
		$rodex_item->{type} = $args->{type};
		$rodex_item->{amount} = $args->{amount};
		$rodex_item->{identified} = $args->{identified};
		$rodex_item->{broken} = $args->{broken};
		$rodex_item->{upgrade} = $args->{upgrade};
		$rodex_item->{cards} = $args->{cards};
		$rodex_item->{options} = $args->{options};
		$rodex_item->{name} = itemName($rodex_item);

		$rodexWrite->{items}->add($rodex_item);
	}
	
	my $disp = TF("Item added to rodex mail message: %s (%d) x %d - %s",
			$rodex_item->{name}, $rodex_item->{binID}, $args->{amount}, $itemTypes_lut{$rodex_item->{type}});
	message "$disp\n", "drop";
}

sub rodex_open_write {
	my ( $self, $args ) = @_;
	
	$rodexWrite = {};
	
	$rodexWrite->{items} = new InventoryList;
	
}

sub rodex_check_player {
	my ( $self, $args ) = @_;
	
	if (!$args->{char_id}) {
		error "Could not find player with name '".$args->{name}."'.";
		return;
	}
	
	my $print_msg = center(" " . "Rodex Mail Target" . " ", 79, '-') . "\n";
	
	$print_msg .= swrite("@<<<<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<< @<<< @<<<<<< @<<<<<<<<<<<<<<< @<<<<<<<< @<<<<<<<<<", ["Name:", $args->{name}, "Base Level:", $args->{base_level}, "Class:", $args->{class}, "Char ID:", $args->{char_id}]);
	
	$print_msg .= sprintf("%s\n", ('-'x79));
	message $print_msg, "list";
	
	@{$rodexWrite->{target}}{qw(name base_level class char_id)} = @{$args}{qw(name base_level class char_id)};
}

sub rodex_write_result {
	my ( $self, $args ) = @_;
	
	if ($args->{fail}) {
		error "You failed to send the rodex mail.\n";
		return;
	}
	
	message "Your rodex mail was sent with success.\n";
	undef $rodexWrite;
}

sub rodex_get_zeny {
	my ( $self, $args ) = @_;
	
	if ($args->{fail}) {
		error "You failed to get the zeny of the rodex mail.\n";
		return;
	}
	
	message "The zeny of the rodex mail was requested with success.\n";
	
	$rodexList->{mails}{$args->{mailID1}}{zeny1} = 0;
}

sub rodex_get_item {
	my ( $self, $args ) = @_;
	
	if ($args->{fail}) {
		error "You failed to get the items of the rodex mail.\n";
		return;
	}
	
	message "The items of the rodex mail were requested with success.\n";
	
	$rodexList->{mails}{$args->{mailID1}}{items} = [];
}

sub rodex_delete {
	my ( $self, $args ) = @_;
	
	return unless (exists $rodexList->{mails}{$args->{mailID1}});
	
	message "You have deleted the mail of ID ".$args->{mailID1}.".\n";
	
	delete $rodexList->{mails}{$args->{mailID1}};
}

# 0x803
sub booking_register_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
		message T("Booking successfully created!\n"), "booking";
	} elsif ($result == 2) {
		error T("You already got a reservation group active!\n"), "booking";
	} else {
		error TF("Unknown error in creating the group booking (Error %s)\n", $result), "booking";
	}
}

# 0x805
sub booking_search_request {
	my ($self, $args) = @_;

	if (length($args->{innerData}) == 0) {
		error T("Without results!\n"), "booking";
		return;
	}

	message T("-------------- Booking Search ---------------\n");
	for (my $offset = 0; $offset < length($args->{innerData}); $offset += 48) {
		my ($index, $charName, $expireTime, $level, $mapID, @job) = unpack("V Z24 V s8", substr($args->{innerData}, $offset, 48));
		message swrite(
			T("Name: \@<<<<<<<<<<<<<<<<<<<<<<<<	Index: \@>>>>\n" .
			"Created: \@<<<<<<<<<<<<<<<<<<<<<	Level: \@>>>\n" .
			"MapID: \@<<<<<\n".
			"Job: \@<<<< \@<<<< \@<<<< \@<<<< \@<<<<\n" .
			"---------------------------------------------"),
			[bytesToString($charName), $index, getFormattedDate($expireTime), $level, $mapID, @job]), "booking";
	}
}

# 0x807
sub booking_delete_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
		message T("Reserve deleted successfully!\n"), "booking";
	} elsif ($result == 3) {
		error T("You're not with a group booking active!\n"), "booking";
	} else {
		error TF("Unknown error in deletion of group booking (Error %s)\n", $result), "booking";
	}
}

# 0x809
sub booking_insert {
	my ($self, $args) = @_;

	message TF("%s has created a new group booking (index: %s)\n", bytesToString($args->{name}), $args->{ID});
}

# 0x80A
sub booking_update {
	my ($self, $args) = @_;

	message TF("Reserve index of %s has changed its settings\n", $args->{ID});
}

# 0x80B
sub booking_delete {
	my ($self, $args) = @_;

	message TF("Deleted reserve group index %s\n", $args->{ID});
}


sub clan_user {
    my ($self, $args) = @_;
    foreach (qw(onlineuser totalmembers)) {
        $clan{$_} = $args->{$_};
    }	
    $clan{onlineuser} = $args->{onlineuser};
    $clan{totalmembers} = $args->{totalmembers};
}

sub clan_info {
    my ($self, $args) = @_;
    foreach (qw(clan_ID clan_name clan_master clan_map alliance_count antagonist_count)) {
        $clan{$_} = $args->{$_};
    }

	$clan{clan_name} = bytesToString($args->{clan_name});
	$clan{clan_master} = bytesToString($args->{clan_master});
	$clan{clan_map} = bytesToString($args->{clan_map});
	
	my $i = 0;
	my $count = 0;
	$clan{ally_names} = "";
	$clan{antagonist_names} = "";

	if($args->{alliance_count} > 0) {
		for ($count; $count < $args->{alliance_count}; $count++) {
			$clan{ally_names} .= bytesToString(unpack("Z24", substr($args->{ally_antagonist_names}, $i, 24))).", ";
			$i += 24;
		}
	}

	$count = 0;
	if($args->{antagonist_count} > 0) {
		for ($count; $count < $args->{antagonist_count}; $count++) {
			$clan{antagonist_names} .= bytesToString(unpack("Z24", substr($args->{ally_antagonist_names}, $i, 24))).", ";
			$i += 24;
		}
	}
}

sub clan_chat {
	my ($self, $args) = @_;
	my ($chatMsgUser, $chatMsg); # Type: String

	return unless changeToInGameState();
	$chatMsgUser = bytesToString($args->{charname});
	$chatMsg = bytesToString($args->{message});

	chatLog("clan", "$chatMsgUser : $chatMsg\n") if ($config{'logClanChat'});
	# Translation Comment: Guild Chat
	message TF("[Clan]%s %s\n", $chatMsgUser, $chatMsg), "clanchat";
	# Only queue this if it's a real chat message
	ChatQueue::add('clan', 0, $chatMsgUser, $chatMsg) if ($chatMsgUser);

	Plugins::callHook('packet_clanMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});
}

sub clan_leave {
	my ($self, $args) = @_;
	
	if($clan{clan_name}) {
		message TF("[Clan] You left %s\n", $clan{clan_name});
		undef %clan;
	}
}


sub change_title {
	my ($self, $args) = @_;
	#TODO : <result>.B
	message TF("You changed Title_ID :  %s.\n", $args->{title_id}), "info";
}


sub pet_evolution_result {
	my ($self, $args) = @_;
	if ($args->{result} == 0x0) {
		error TF("Pet evolution error.\n");
	#PET_EVOL_NO_CALLPET = 0x1,
	#PET_EVOL_NO_PETEGG = 0x2,
	} elsif ($args->{result} == 0x3) {
		error TF("Unequip pet accessories first to start evolution.\n");
	} elsif ($args->{result} == 0x4) {
		error TF("Insufficient materials for evolution.\n");
	} elsif ($args->{result} == 0x5) {	
		error TF("Loyal Intimacy is required to evolve.\n");
	} elsif ($args->{result} == 0x6) {
		message TF("Pet evolution success.\n"), "success";
	}
}

sub elemental_info {
	my ($self, $args) = @_;

	$char->{elemental} = Actor::get($args->{ID}) if ($char->{elemental}{ID} ne $args->{ID});
	if (!defined $char->{elemental}) {	
		$char->{elemental} = new Actor::Elemental;
	}

	foreach (@{$args->{KEYS}}) {
		$char->{elemental}{$_} = $args->{$_};
	}
}

# 0221
sub upgrade_list {
	my ($self, $args) = @_;
	undef $refineList;
	my $k = 0;
	my $msg;

	$msg .= center(" " . T("Upgrade List") . " ", 79, '-') . "\n";

	for (my $i = 0; $i < length($args->{item_list}); $i += 13) {
		my ($index, $nameID) = unpack('a2 x6 C', substr($args->{item_list}, $i, 13));
		my $item = $char->inventory->getByID($index);
		$refineList->[$k] = unpack('v', $item->{ID});
		$msg .= swrite(sprintf("\@%s - \@%s (\@%s)", ('<'x2), ('<'x50), ('<'x3)), [$k, itemName($item), $item->{binID}]);
		$k++;
	}

	$msg .= sprintf("%s\n", ('-'x79));

	message($msg, "list");
	message T("You can now use the 'refine' command.\n"), "info";
}

# 025A
sub cooking_list {
	my ($self, $args) = @_;
	undef $cookingList;
	undef $currentCookingType;
	my $k = 0;
	my $msg;
	$currentCookingType = $args->{type};
	$msg .= center(" " . T("Cooking List") . " ", 79, '-') . "\n";
	for (my $i = 0; $i < length($args->{item_list}); $i += 2) {
		my $nameID = unpack('v', substr($args->{item_list}, $i, 2));
		$cookingList->[$k] = $nameID;
		$msg .= swrite(sprintf("\@%s \@%s", ('>'x2), ('<'x50)), [$k, itemNameSimple($nameID)]);
		$k++;
	}
	$msg .= sprintf("%s\n", ('-'x79));

	message($msg, "list");
	message T("You can now use the 'cook' command.\n"), "info";

	Plugins::callHook('cooking_list', {
		cooking_list => $cookingList,
	});
}

sub refine_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message TF("You successfully refined a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 1) {
		message TF("You failed to refine a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 2) {
		message TF("You successfully made a potion (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 3) {
		message TF("You failed to make a potion (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 6) {
		message TF("You successfully cook a item (ID %s)!\n", $args->{nameID});
	} else {
		message TF("You tried to refine a weapon (ID %s); result: unknown %s\n", $args->{nameID}, $args->{fail});
	}
}

1;