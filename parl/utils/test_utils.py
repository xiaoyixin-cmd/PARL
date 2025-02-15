#   Copyright (c) 2023 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import unittest
from parl.utils import get_free_tcp_port
import multiprocessing as mp
from parl.remote.master import Master
from parl.remote.worker import Worker
from parl.remote.client import disconnect
import time

class XparlTestCase(unittest.TestCase):
    def setUp(self):
        self.port = get_free_tcp_port()
        self.ctx = mp.get_context()
        self.sub_process = []
        self.worker_process = []

    def tearDown(self):
        for p in self.sub_process:
            if p.is_alive():
                p.terminate()
                p.join()
        disconnect()

    def _create_master(self):
        master = Master(port=self.port)
        master.run()

    def _create_worker(self, n_cpu):
        worker = Worker('localhost:{}'.format(self.port), n_cpu)
        worker.run()

    def add_master(self):
        p_master = self.ctx.Process(target=self._create_master)
        p_master.start()
        self.sub_process.append(p_master)
        time.sleep(1)

    def add_worker(self, n_cpu):
        p_worker = self.ctx.Process(target=self._create_worker, args=(n_cpu, ))
        p_worker.start()
        time.sleep(10)
        self.sub_process.append(p_worker)
        self.worker_process.append(p_worker)

    def remove_all_workers(self):
        for p in self.worker_process:
            if p.is_alive():
                p.terminate()
                p.join()
