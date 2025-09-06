from locust import FastHttpUser, task, between, events  
import random
import os, time
from base64 import b64encode

# Set heartbeat config via Python
@events.init.add_listener
def on_locust_init(environment, **kwargs):
    runner = environment.runner
    if runner and hasattr(runner, "heartbeat_interval"):
        runner.master.heartbeat_interval = 10   # default is 1
        runner.master.heartbeat_timeout = 300   # default is 60

N_ACTOR = 200

class NextcloudUser(FastHttpUser):
    wait_time = between(10, 60)
    SUFFIX_PASSWORD = "sole@mare"

    def on_start(self):
        idx = random.randint(0, N_ACTOR)
        self.USERNAME = f"user{idx}"
        pwd = f"{self.SUFFIX_PASSWORD}{idx}"
        self.auth_header = {
            "Authorization": "Basic " + b64encode(f"{self.USERNAME}:{pwd}".encode()).decode()
        }

    # ---------- helpers ----------
    def _upload_file(self, local_name, remote_name, label):
        with open(f"/mnt/locust/{local_name}", "rb") as f:
            self.client.put(
                f"/remote.php/dav/files/{self.USERNAME}/{remote_name}",
                data=f,
                headers=self.auth_header,
                name=f"PUT_{label}",
                timeout=1800,   # 30 min
            )

    # ---------- tasks ------------
    @task(30)
    def small(self):
        self._upload_file("1KB__file", f"kb_{time.time()}", "1KB")

    @task(30)
    def medium(self):
        self._upload_file("1MB__file", f"mb_{time.time()}", "1MB")

    @task(1)
    def image(self):
        self._upload_file("spacex.jpeg", f"img_{time.time()}.jpeg", "image")

    @task(1)
    def big(self):
        self._upload_file("1GB__file", f"gb_{time.time()}", "1GB")

    @task(4)
    def list(self):
        self.client.request(
            "PROPFIND",
            f"/remote.php/dav/files/{self.USERNAME}/",
            headers={**self.auth_header, "Depth": "1"},
            name="PROPFIND_list",
        )
