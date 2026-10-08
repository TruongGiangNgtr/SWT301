"""Execute the actual Postman collection with Newman against an owned local server."""
import json,os,signal,subprocess,sys,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=Path(os.environ.get("POSTMAN_RESULTS",ROOT/"TestResults/postman")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
env.update({"ASPNETCORE_ENVIRONMENT":"Development","DOTNET_ENVIRONMENT":"Development","Logging__LogLevel__Default":"Warning",
"Logging__LogLevel__Microsoft.Hosting.Lifetime":"Information"})
for name in ["ASPNETCORE_URLS","ASPNETCORE_HTTP_PORTS","ASPNETCORE_HTTPS_PORTS","DOTNET_URLS"]:env.pop(name,None)
metadata={"status":"NotExecuted","serverStopped":False}
server=None
try:
    with open(OUT/"server.log","w",encoding="utf-8") as log:
        server=subprocess.Popen(["dotnet","run","--project",str(ROOT/"apps/web/SWT.csproj"),"-c","Release",
            "--no-build","--no-restore","--no-launch-profile","--","--urls","http://127.0.0.1:5081"],
            cwd=ROOT/"apps/web",env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=os.name!="nt")
        deadline=time.monotonic()+45
        ready=False
        while time.monotonic()<deadline:
            if server.poll() is not None:raise RuntimeError("Owned server exited; inspect server.log")
            try:
                with urllib.request.urlopen("http://127.0.0.1:5081",timeout=2) as response:ready=response.status==200
                if ready:break
            except OSError:pass
            time.sleep(.2)
        if not ready:raise TimeoutError("Local API readiness")
        command=["node",str(ROOT/"tests/api/node_modules/newman/bin/newman.js"),"run",
            str(ROOT/"tests/api/DateTimeChecker.postman_collection.json"),"--env-var","baseUrl=http://127.0.0.1:5081",
            "--reporters","cli,json","--reporter-json-export",str(OUT/"newman.json"),"--timeout-request","10000","--color","off"]
        run=subprocess.run(command,env=env,cwd=ROOT,capture_output=True,text=True,timeout=120)
        (OUT/"execution.log").write_text(run.stdout+run.stderr,encoding="utf-8")
        print(run.stdout)
        metadata.update(exitCode=run.returncode,status="Passed" if run.returncode==0 else "Failed")
        report=json.loads((OUT/"newman.json").read_text(encoding="utf-8"))
        metadata["stats"]=report["run"]["stats"]
        assert run.returncode==0 and report["run"]["stats"]["requests"]["total"]==19 and not report["run"]["failures"]
finally:
    if server is not None and server.poll() is None:
        if os.name=="nt":subprocess.run(["taskkill","/PID",str(server.pid),"/T","/F"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        else:os.killpg(server.pid,signal.SIGTERM)
        try:server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            if os.name!="nt":os.killpg(server.pid,signal.SIGKILL)
            server.wait(timeout=10)
    metadata["serverStopped"]=server is None or server.poll() is not None
    (OUT/"run.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
