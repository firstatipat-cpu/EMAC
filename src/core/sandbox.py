import docker
import os
import time

class DockerSandbox:
    def __init__(self):
        try:
            self.client = docker.from_env()
            self.image = "python:3.10-slim"
            self.container = None
            self.working_dir = "/app"
            self._start_persistent_container()
        except: self.client = None

    def _start_persistent_container(self):
        abs_path = os.path.abspath("workspace")
        try:
            try:
                old = self.client.containers.get("emacs-sandbox")
                old.remove(force=True)
            except: pass

            self.container = self.client.containers.run(
                self.image,
                name="emacs-sandbox",
                command="tail -f /dev/null",
                volumes={abs_path: {'bind': self.working_dir, 'mode': 'rw'}},
                working_dir=self.working_dir,
                detach=True,
                mem_limit="512m",
                network_disabled=False
            )
            print("📦 Sandbox Started")
        except: pass

    def run_code(self, filename: str, dependencies: list = []) -> str:
        if not self.container: return "Sandbox Not Running"
        
        if dependencies:
            self.container.exec_run(f"pip install {' '.join(dependencies)}")
        
        cmd = f"python -u {filename}"
        exit_code, output = self.container.exec_run(cmd)
        
        logs = output.decode("utf-8")
        if exit_code != 0:
            return f"Error (Exit Code {exit_code}):\n{logs}"
        return logs if logs else "(No Output)"

    def run_shell(self, command: str) -> str:
        if not self.container: return "Sandbox Not Running"
        exit_code, output = self.container.exec_run(command)
        return output.decode("utf-8")
