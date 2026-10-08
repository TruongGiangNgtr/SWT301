"""Manage owned API/Appium servers; caller supplies a running emulator and built APK."""
import json,os,signal,subprocess,sys,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=Path(os.environ.get("MOBILE_RESULTS",ROOT/"TestResults/mobile")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
env.update({"ASPNETCORE_ENVIRONMENT":"Development","DOTNET_ENVIRONMENT":"Development",
"Logging__LogLevel__Default":"Warning","Logging__LogLevel__Microsoft.Hosting.Lifetime":"Information",
"APPIUM_HOME":str(ROOT/".appium"),"MOBILE_RESULTS":str(OUT),
"ANDROID_APK":str(ROOT/"apps/mobile/app/build/outputs/apk/debug/app-debug.apk")})
for name in ["ASPNETCORE_URLS","ASPNETCORE_HTTP_PORTS","ASPNETCORE_HTTPS_PORTS","DOTNET_URLS"]:env.pop(name,None)
processes=[];streams=[];metadata={"status":"NotExecuted","serversStopped":False}
def start(command,cwd,log):
    stream=open(OUT/log,"w",encoding="utf-8");streams.append(stream)
    process=subprocess.Popen(command,cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=os.name!="nt")
    processes.append(process);return process
def ready(process,url,budget):
    deadline=time.monotonic()+budget
    while time.monotonic()<deadline:
        if process.poll() is not None:raise RuntimeError(f"Owned process exited: {process.returncode}; inspect logs")
        try:
            with urllib.request.urlopen(url,timeout=2) as response:
                if response.status==200:return
        except (OSError,ValueError):pass
        time.sleep(.2)
    raise TimeoutError(url)
try:
    if not Path(env["ANDROID_APK"]).is_file():raise FileNotFoundError(env["ANDROID_APK"])
    api=start(["dotnet","run","--project",str(ROOT/"apps/web/SWT.csproj"),"-c","Release","--no-build",
        "--no-restore","--no-launch-profile","--","--urls","http://127.0.0.1:5080"],ROOT/"apps/web","api-server.log")
    ready(api,"http://127.0.0.1:5080/",45)
    appium=start(["node",str(ROOT/"tests/mobile-e2e/node_modules/appium/index.js"),
        "--address","127.0.0.1","--port","4723","--log-no-colors"],ROOT/"tests/mobile-e2e","appium-server.log")
    ready(appium,"http://127.0.0.1:4723/status",60);metadata["status"]="Running"
    with open(OUT/"execution.log","w",encoding="utf-8") as log:
        run=subprocess.run([sys.executable,str(ROOT/"tests/mobile-e2e/test_mobile.py")],
            cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    metadata.update(status="Passed" if run.returncode==0 else "Failed",exitCode=run.returncode)
    print((OUT/"execution.log").read_text(encoding="utf-8"))
    if run.returncode:raise RuntimeError("Appium assertions failed; inspect results.json/screenshots")
except Exception as error:
    metadata.update(status="Failed",error=str(error));raise
finally:
    for process in reversed(processes):
        if process.poll() is None:
            if os.name=="nt":subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            else:os.killpg(process.pid,signal.SIGTERM)
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                if os.name!="nt":os.killpg(process.pid,signal.SIGKILL)
                process.wait(timeout=10)
    for stream in streams:stream.close()
    metadata["serversStopped"]=all(p.poll() is not None for p in processes)
    (OUT/"run.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
