"""Real native Appium/UiAutomator2 assertions via W3C WebDriver HTTP."""
import base64, json, os, time, unittest, urllib.request, urllib.error
from pathlib import Path
OUT=Path(os.environ.get("MOBILE_RESULTS","TestResults/mobile")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
SERVER=os.environ.get("APPIUM_URL","http://127.0.0.1:4723").rstrip("/")
PREFIX="com.swt301.datetimechecker:id/"
ELEMENT="element-6066-11e4-a52e-4f735466cecf"
def wire(method,path,body=None):
    data=None if body is None else json.dumps(body).encode()
    request=urllib.request.Request(SERVER+path,data=data,method=method,headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(request,timeout=120) as response:result=json.load(response)
    except urllib.error.HTTPError as error:raise RuntimeError(error.read().decode()) from error
    value=result.get("value")
    if isinstance(value,dict) and value.get("error"):raise RuntimeError(str(value))
    return value
class MobileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        caps={"platformName":"Android","appium:automationName":"UiAutomator2",
            "appium:deviceName":"SWT301 Emulator","appium:udid":os.environ.get("ANDROID_SERIAL","emulator-5554"),
            "appium:app":str(Path(os.environ["ANDROID_APK"]).resolve()),
            "appium:appPackage":"com.swt301.datetimechecker","appium:appActivity":".MainActivity",
            "appium:newCommandTimeout":120,"appium:androidInstallTimeout":120000,
            "appium:adbExecTimeout":60000,"appium:noReset":False}
        cls.session=wire("POST","/session",{"capabilities":{"alwaysMatch":caps,"firstMatch":[{}]}})["sessionId"]
    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,"session"):wire("DELETE",f"/session/{cls.session}")
    def call(self,method,path,data=None):return wire(method,f"/session/{self.session}"+path,data)
    def find(self,name):return self.call("POST","/element",{"using":"id","value":PREFIX+name})[ELEMENT]
    def text(self,name):return self.call("GET",f"/element/{self.find(name)}/text")
    def click(self,name):self.call("POST",f"/element/{self.find(name)}/click",{})
    def fill(self,name,value):
        element=self.find(name);self.call("POST",f"/element/{element}/clear",{})
        self.call("POST",f"/element/{element}/value",{"text":str(value),"value":list(str(value))})
    def hide_keyboard(self):
        try:self.call("POST","/appium/device/hide_keyboard",{})
        except RuntimeError as error:
            if "not present" not in str(error).lower() and "cannot hide" not in str(error).lower():raise
    def setUp(self):self.click("clear")
    def input(self,day,month,year):
        self.fill("day",day);self.fill("month",month);self.fill("year",year);self.hide_keyboard()
    def wait_result(self,expected):
        deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            if self.text("result")==expected:return
            time.sleep(.2)
        self.assertEqual(expected,self.text("result"))
    def tearDown(self):
        try:(OUT/(self._testMethodName+".png")).write_bytes(base64.b64decode(self.call("GET","/screenshot")))
        except Exception as error:
            (OUT/(self._testMethodName+"-capture-error.json")).write_text(json.dumps({"error":str(error)}),encoding="utf-8")
    def test_launch_and_controls(self):
        self.assertEqual("Date Time Checker",self.text("title"))
        for name in ["day","month","year","api_url","check","clear","result"]:self.find(name)
    def test_valid_date(self):
        self.input(29,2,2000);self.click("check");self.wait_result("29/02/2000 is correct date time!")
    def test_invalid_century_date(self):
        self.input(29,2,1900);self.click("check");self.wait_result("29/02/1900 is NOT correct date time!")
    def test_input_validation(self):
        self.input("abc",2,2000);self.click("check");self.wait_result("Input data must be integers.")
    def test_clear(self):
        self.input(29,2,2000);self.click("check");self.wait_result("29/02/2000 is correct date time!");self.click("clear")
        for name in ["day","month","year","result"]:self.assertEqual("",self.text(name))
if __name__=="__main__":
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(MobileTests)
    expected=suite.countTestCases();names=[test._testMethodName for test in suite]
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    data={"discovered":expected,"testNames":names,"executed":result.testsRun,"failed":len(result.failures),
        "errors":len(result.errors),"skipped":len(result.skipped),
        "passed":max(0,result.testsRun-len(result.failures)-len(result.errors)-len(result.skipped)),
        "status":"Passed" if result.wasSuccessful() and result.testsRun==5 else "EnvironmentBlocked" if result.testsRun==0 else "Failed",
        "failures":[{"test":str(test),"trace":trace} for test,trace in result.failures+result.errors],
        "environment":{"platform":"Android","automation":"Appium 2.19.0 / UiAutomator2 4.2.9",
            "udid":os.environ.get("ANDROID_SERIAL","emulator-5554")}}
    (OUT/"results.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
    raise SystemExit(0 if expected==5 and result.testsRun==5 and result.wasSuccessful() and not result.skipped else 1)
