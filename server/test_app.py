import os
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("FIREBASE_PROJECT_ID", "test-project")

import app as api


class ProgressApiTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        api.DATABASE_PATH = os.path.join(self.temp_dir.name, "progress.sqlite3")
        self.client = api.app.test_client()

    def tearDown(self):
        self.temp_dir.cleanup()

    @patch("app.verify_firebase_id_token", side_effect=lambda token: token)
    def test_progress_is_stored_by_verified_uid(self, _verify):
        saved = self.client.put(
            "/v1/progress",
            headers={"Authorization": "Bearer uid-a"},
            json={"data": {"version": 3, "favorites": {"karimen": ["q1"]}}},
        )
        self.assertEqual(saved.status_code, 200)

        loaded = self.client.get(
            "/v1/progress",
            headers={"Authorization": "Bearer uid-a"},
        )
        self.assertEqual(loaded.status_code, 200)
        self.assertEqual(loaded.json["data"]["favorites"]["karimen"], ["q1"])

        other_user = self.client.get(
            "/v1/progress",
            headers={"Authorization": "Bearer uid-b"},
        )
        self.assertEqual(other_user.status_code, 404)


if __name__ == "__main__":
    unittest.main()
