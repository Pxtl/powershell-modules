namespace Pxtl.ADServices
{
    /// <summary>
    /// LDAP userAccountControl attribute bit-flags
    /// </summary>
    /// <remarks>
    /// See https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties
    /// </remarks>
    internal static class UserAccountControlFlags
    {
        public const int SCRIPT = 0x01;
        public const int ACCOUNT_DISABLED = 0x02;
        public const int HOMEDIR_REQUIRED = 0x08;
        public const int LOCKOUT = 0x10;
        public const int PASSWD_NOTREQD = 0x20;
        public const int PASSWD_CANT_CHANGE = 0x40;
        public const int ENCRYPTED_TEXT_PWD_ALLOWED = 0x80;
        public const int DONT_EXPIRE_PASSWORD = 0x10000;
        public const int MNS_LOGON_ACCOUNT = 0x20000;
        public const int SMARTCARD_REQUIRED = 0x40000;
        public const int TRUSTED_FOR_DELEGATION = 0x80000;
        public const int NOT_DELEGATED = 0x100000;
        public const int USE_DES_KEY_ONLY = 0x200000;
        public const int DONT_REQ_PREAUTH = 0x400000;
        public const int PASSWORD_EXPIRED = 0x800000;
        public const int TRUSTED_TO_AUTH_FOR_DELEGATION = 0x1000000;
    }
}