using System;
using System.Collections;
using System.IO;
using System.Management.Automation;
using System.Net;
using Microsoft.VisualStudio.TestTools.UnitTesting;

using Pxtl.ADServices;

namespace Pxtl.ADServices.Tests
{
    [TestClass]
    public class ADEntryRepositoryTests
    {
        private readonly string _server = "localhost:389";
        private PSCredential _credential = null;

        [TestInitialize]
        public void TestInitialize()
        {
            _credential = ConvertToPSCredential(new NetworkCredential("Administrator", "Passw0rd"));
        }
        
        [TestMethod]
        public void TestGetRootDSE()
        {
            var rootDSE = ADEntryRepository.MaybeGetADObject<ADRootDSEEntry>("(objectClass=*)", null, null, _server, _credential);
            Assert.IsNotNull(rootDSE, "rootDSE is null");
            Assert.IsTrue(rootDSE.Attributes.ContainsKey("defaultNamingContext"), "rootDSE does not have defaultNamingContext");
        }

        [TestMethod]
        public void TestNewADOrganizationalUnit()
        {
            var expectedOUName = "MSTestOU";
            var entry = ADEntryRepository.NewADObject(ADEntryType.OrganizationalUnit, "OU", expectedOUName, null, null, null, _server, _credential, false, true);
            var identity = entry?.MaybeGetDistinguishedName();

            ADEntryRepository.RemoveADObject<ADOrganizationalUnitEntry>(identity, _server, _credential);
        }

        [TestMethod]
        public void TestNewADUserUnit()
        {
            var expectedUserName = "msTestUser1";
            var entry = ADEntryRepository.NewADObject(ADEntryType.User, "CN", expectedUserName, null, null, null, _server, _credential, false, true);
            var identity = entry?.MaybeGetDistinguishedName();

            ADEntryRepository.RemoveADObject<ADUserEntry>(identity, _server, _credential);
        }

        private static PSCredential ConvertToPSCredential(NetworkCredential networkCredential)
            => new PSCredential(networkCredential.UserName, networkCredential.SecurePassword);
    }
}
