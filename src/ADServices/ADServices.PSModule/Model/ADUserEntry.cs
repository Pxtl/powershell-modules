using System;
using System.Collections.Generic;

namespace Pxtl.ADServices
{
    public class ADUserEntry : ADObjectEntry
    {
        public DateTime? AccountExpirationDate { get; set; }
        public DateTime? AccountLockoutTime { get; set; }
        public bool AccountNotDelegated { get; set; }
        public bool AllowReversiblePasswordEncryption { get; set; }
        public object BadLogonCount { get; set; }
        public object CannotChangePassword { get; set; }
        public object Certificates { get; set; }
        public bool ChangePasswordAtLogon { get; set; }
        public object City { get; set; }
        public object Company { get; set; }
        public object Country { get; set; }
        public object Department { get; set; }
        public object Division { get; set; }
        public bool DoesNotRequirePreAuth { get; set; }
        public object EmailAddress { get; set; }
        public object EmployeeID { get; set; }
        public object EmployeeNumber { get; set; }
        public bool Enabled { get; set; }
        public string Fax { get; set; }
        public object GivenName { get; set; }
        public object HomeDirectory { get; set; }
        public bool HomedirRequired { get; set; }
        public object HomeDrive { get; set; }
        public object HomePage { get; set; }
        public object HomePhone { get; set; }
        public object Initials { get; set; }
        public DateTime? LastBadPasswordAttempt { get; set; }
        public DateTime? LastLogonDate { get; set; }
        public bool LockedOut { get; set; }
        public object LogonWorkstations { get; set; }
        public object Manager { get; set; }
        public object MemberOf { get; set; }
        public bool MNSLogonAccount { get; set; }
        public object MobilePhone { get; set; }
        public object Office { get; set; }
        public object OfficePhone { get; set; }
        public object Organization { get; set; }
        public object OtherName { get; set; }
        public bool PasswordExpired { get; set; }
        public DateTime? PasswordLastSet { get; set; }
        public bool PasswordNeverExpires { get; set; }
        public bool PasswordNotRequired { get; set; }
        public object POBox { get; set; }
        public object PostalCode { get; set; }
        public object PrimaryGroup { get; set; }
        public object ProfilePath { get; set; }
        public string SamAccountName { get; set; }
        public object ScriptPath { get; set; }
        public object ServicePrincipalNames { get; set; }
        public string SID { get; set; }
        public object SIDHistory { get; set; }
        public bool SmartcardLogonRequired { get; set; }
        public object State { get; set; }
        public object StreetAddress { get; set; }
        public object Surname { get; set; }
        public object Title { get; set; }
        public bool TrustedForDelegation { get; set; }
        public bool TrustedToAuthForDelegation { get; set; }
        public bool UseDESKeyOnly { get; set; }
        public string UserPrincipalName { get; set; }

        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
            AccountExpirationDate = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "accountExpires"));
            AccountLockoutTime = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "lockoutTime"));
            AccountNotDelegated = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.ACCOUNT_DISABLED);
            AllowReversiblePasswordEncryption = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.ENCRYPTED_TEXT_PWD_ALLOWED);
            BadLogonCount = ADAttributeHelper.GetValue(ldapAttributes, "badPwdCount");
            CannotChangePassword = ADAttributeHelper.GetValue(ldapAttributes, "nTSecurityDescriptor");
            Certificates = ADAttributeHelper.GetValue(ldapAttributes, "userCertificate");
            ChangePasswordAtLogon = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "pwdLastSet")) == DateTime.MinValue;
            City = ADAttributeHelper.GetValue(ldapAttributes, "l");
            Company = ADAttributeHelper.GetValue(ldapAttributes, "company");
            Country = ADAttributeHelper.GetValue(ldapAttributes, "c");
            Department = ADAttributeHelper.GetValue(ldapAttributes, "department");
            Division = ADAttributeHelper.GetValue(ldapAttributes, "division");
            DoesNotRequirePreAuth = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.DONT_REQ_PREAUTH);
            EmailAddress = ADAttributeHelper.GetValue(ldapAttributes, "mail");
            EmployeeID = ADAttributeHelper.GetValue(ldapAttributes, "employeeID");
            EmployeeNumber = ADAttributeHelper.GetValue(ldapAttributes, "employeeNumber");
            Enabled = !ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.ACCOUNT_DISABLED);
            Fax = ADAttributeHelper.GetValue(ldapAttributes, "facsimileTelephoneNumber")?.ToString();
            GivenName = ADAttributeHelper.GetValue(ldapAttributes, "givenName");
            HomeDirectory = ADAttributeHelper.GetValue(ldapAttributes, "homeDirectory");
            HomedirRequired = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.HOMEDIR_REQUIRED);
            HomeDrive = ADAttributeHelper.GetValue(ldapAttributes, "homeDrive");
            HomePage = ADAttributeHelper.GetValue(ldapAttributes, "wWWHomePage");
            HomePhone = ADAttributeHelper.GetValue(ldapAttributes, "homePhone");
            Initials = ADAttributeHelper.GetValue(ldapAttributes, "initials");
            LastBadPasswordAttempt = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "badPasswordTime"));
            LastLogonDate = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "lastLogonTimeStamp"));
            LockedOut = ADAttributeHelper.HasFlag(ldapAttributes, "msDS-User-Account-Control-Computed", UserAccountControlFlags.LOCKOUT);
            LogonWorkstations = ADAttributeHelper.GetValue(ldapAttributes, "userWorkstations");
            Manager = ADAttributeHelper.GetValue(ldapAttributes, "manager");
            MemberOf = ADAttributeHelper.GetValue(ldapAttributes, "memberOf");
            MNSLogonAccount = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.MNS_LOGON_ACCOUNT);
            MobilePhone = ADAttributeHelper.GetValue(ldapAttributes, "mobile");
            Office = ADAttributeHelper.GetValue(ldapAttributes, "physicalDeliveryOfficeName");
            OfficePhone = ADAttributeHelper.GetValue(ldapAttributes, "telephoneNumber");
            Organization = ADAttributeHelper.GetValue(ldapAttributes, "o");
            OtherName = ADAttributeHelper.GetValue(ldapAttributes, "middleName");
            PasswordExpired = ADAttributeHelper.HasFlag(ldapAttributes, "msDS-User-Account-Control-Computed", UserAccountControlFlags.PASSWORD_EXPIRED);
            PasswordLastSet = LdapHelper.ConvertFileTime(ADAttributeHelper.GetValue(ldapAttributes, "pwdLastSet"));
            PasswordNeverExpires = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.DONT_EXPIRE_PASSWORD);
            PasswordNotRequired = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.PASSWD_NOTREQD);
            POBox = ADAttributeHelper.GetValue(ldapAttributes, "postOfficeBox");
            PostalCode = ADAttributeHelper.GetValue(ldapAttributes, "postalCode");
            PrimaryGroup = ADAttributeHelper.GetValue(ldapAttributes, "primaryGroupID");
            ProfilePath = ADAttributeHelper.GetValue(ldapAttributes, "profilePath");
            SamAccountName = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "sAMAccountName"));
            ScriptPath = ADAttributeHelper.GetValue(ldapAttributes, "scriptPath");
            ServicePrincipalNames = ADAttributeHelper.GetValue(ldapAttributes, "servicePrincipalName");
            SID = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "objectSID"));
            SIDHistory = ADAttributeHelper.GetValue(ldapAttributes, "sIDHistory");
            SmartcardLogonRequired = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.SMARTCARD_REQUIRED);
            State = ADAttributeHelper.GetValue(ldapAttributes, "st");
            StreetAddress = ADAttributeHelper.GetValue(ldapAttributes, "streetAddress");
            Surname = ADAttributeHelper.GetValue(ldapAttributes, "sn");
            Title = ADAttributeHelper.GetValue(ldapAttributes, "title");
            TrustedForDelegation = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.TRUSTED_FOR_DELEGATION);
            TrustedToAuthForDelegation = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.TRUSTED_TO_AUTH_FOR_DELEGATION);
            UseDESKeyOnly = ADAttributeHelper.HasFlag(ldapAttributes, "userAccountControl", UserAccountControlFlags.USE_DES_KEY_ONLY);
            UserPrincipalName = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "userPrincipalName"));
        }
    }
}
