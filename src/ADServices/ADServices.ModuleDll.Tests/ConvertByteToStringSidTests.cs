using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Security.Principal;

using Pxtl.ADServices;
using System.Reflection;
using System.Text.RegularExpressions;

namespace Pxtl.ADServices.Tests
{
    /// <summary>
    /// Tests for ConvertByteToStringSid, needed because it took some work to adapt it to NET48.
    /// Copied and adapted from https://gist.github.com/thohng/8820153f7d1e107b6619b34fd765f887
    /// </summary>
    [TestClass]
    public class ConvertByteToStringSidTests
    {
        private static Func<byte[], string> GetConvertByteToStringSidService() => LdapHelper.ConvertByteToStringSid;

        [ClassInitialize]
        public static void ClassInitialize(TestContext testContext)
        {
            // System.Memory as loaded in by ADServices.PSModule is incompatible
            // with NET48, so we have to swap in the System.Memory that's
            // available here.

            // code from https://shrivastavaakash.github.io/blog/binding-redirects-without-config
            var currentDomain = AppDomain.CurrentDomain;
            currentDomain.AssemblyResolve += (sender, args) => {
                // Get just the name of assmebly
                // Aseembly name excluding version and other metadata
                string name = new Regex(",.*").Replace(args.Name, string.Empty);

                // Load whatever version available
                return Assembly.Load(name);
            };
        }

        [TestMethod]
        public void ConvertByteToStringSid_Builtin()
        {
            var service = GetConvertByteToStringSidService();
            var sid = new byte[] { 1, 2, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0, 39, 2, 0, 0 };
            var result = service(sid);
            Assert.AreEqual("S-1-5-32-551", result);
        }

        [TestMethod]
        [SupportedOSPlatform("windows")]
        public void ConvertByteToStringSid_Builtin_Windows()
        {
            var sid = new byte[] { 1, 2, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0, 39, 2, 0, 0 };
            var s2 = new SecurityIdentifier(sid, 0);
            Assert.AreEqual("S-1-5-32-551", s2.ToString());
        }

        [TestMethod]
        public void ConvertByteToStringSid_Malformed()
        {
            var service = GetConvertByteToStringSidService();

            var sid1 = new byte[] { 1, 5, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0, 1 };
            var result1 = service(sid1);
            Assert.AreEqual("", result1);

            var sid2 = new byte[] { 1, 5, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0 };
            var result2 = service(sid2);
            Assert.AreEqual("", result2);

            var sid3 = new byte[] { 1, 4, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0 };
            var result3 = service(sid3);
            Assert.AreEqual("", result3);
        }

        [TestMethod]
        public void ConvertByteToStringSid_Max()
        {
            var service = GetConvertByteToStringSidService();

            var sid = new byte[] { 1, 1, 255, 254, 253, 252, 0, 0, 251, 250, 249, 248 };
            var result = service(sid);
            Assert.AreEqual("S-1-281470647926784-4177132283", result);

            var sid2 = new byte[] { 1, 5, 136, 0, 44, 89, 0xFE, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0 };
            var result2 = service(sid2);
            Assert.AreEqual("S-1-149534325472773-21-71093982-54227939-39018152-1025", result2);
        }

        [TestMethod]
        [SupportedOSPlatform("windows")]
        public void ConvertByteToStringSid_Max_Windows()
        {
            var sid = new byte[] { 1, 1, 255, 254, 253, 252, 0, 0, 251, 250, 249, 248 };
            var s1 = new SecurityIdentifier(sid, 0);
            Assert.AreEqual("S-1-281470647926784-4177132283", s1.ToString());

            var sid2 = new byte[] { 1, 5, 136, 0, 44, 89, 0xFE, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0 };
            var s2 = new SecurityIdentifier(sid2, 0);
            Assert.AreEqual("S-1-149534325472773-21-71093982-54227939-39018152-1025", s2.ToString());
        }

        [TestMethod]
        public void ConvertByteToStringSid_NullEmpty()
        {
            var service = GetConvertByteToStringSidService();

            var sid1 = Array.Empty<byte>();
            var result1 = service(sid1);
            Assert.AreEqual("", result1);

            var result2 = service(null);
            Assert.AreEqual("", result2);
        }

        [TestMethod]
        public void ConvertByteToStringSid_Success()
        {
            var service = GetConvertByteToStringSidService();
            var sid = new byte[] { 1, 5, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0 };
            var result = service(sid);
            Assert.AreEqual("S-1-5-21-71093982-54227939-39018152-1025", result);
        }

        [TestMethod]
        [SupportedOSPlatform("windows")]
        public void ConvertByteToStringSid_Windows()
        {
            var sid = new byte[] { 1, 5, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0, 222, 206, 60, 4, 227, 115, 59, 3, 168, 94, 83, 2, 1, 4, 0, 0 };
            var s1 = new SecurityIdentifier(sid, 0);
            Assert.AreEqual("S-1-5-21-71093982-54227939-39018152-1025", s1.ToString());
        }
    }

    //HACK: From
    //https://developercommunity.microsoft.com/t/Support-SupportedOSPlatformAttribute-an/10572666,
    //SupportedOSPlatform can be polyfilled on DotNetStandard2.0 by creating an
    //internal dummy attribute of the same name.

    [System.AttributeUsage(System.AttributeTargets.Assembly | System.AttributeTargets.Class | System.AttributeTargets.Constructor | System.AttributeTargets.Enum | System.AttributeTargets.Event | System.AttributeTargets.Field | System.AttributeTargets.Interface | System.AttributeTargets.Method | System.AttributeTargets.Module | System.AttributeTargets.Property | System.AttributeTargets.Struct, AllowMultiple = true, Inherited = false)]
    internal sealed class SupportedOSPlatformAttribute : System.Attribute
    {
        public string PlatformName { get;set;}
        internal SupportedOSPlatformAttribute(string platformName)
        {
            PlatformName = platformName;
        }
    }
}
