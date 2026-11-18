"""Offline iOS-27 simulator selection checks for GitHub's Xcode runner."""
import unittest
from pick_simulator import choose

IOS_270 = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
IOS_271 = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"
IOS_272 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
IOS_273 = "com.apple.CoreSimulator.SimRuntime.iOS-27-3"
IOS_262 = "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
A = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
B = "11111111-2222-3333-4444-555555555555"
D = "00000000-0000-0000-0000-000000000000"


def device(name, udid, available=True):
    return {"name": name, "udid": udid, "isAvailable": available}


class PickSimulatorTests(unittest.TestCase):
    def test_latest_compatible_regular_iphone(self):
        d = {"devices": {IOS_270: [device("iPhone 17", A)], IOS_272: [device("iPhone 18 Pro", B)]}}
        self.assertEqual(choose(d, "27.2"), (B, "iPhone 18 Pro", "iOS 27.2"))

    def test_older_xcode_avoids_newer_runtime_and_duo(self):
        d = {"devices": {IOS_270: [device("iPhone 17", A)], IOS_271: [device("iPhone Duo", D)], IOS_272: [device("iPhone 18 Pro", B)]}}
        self.assertEqual(choose(d, "27.1"), (A, "iPhone 17", "iOS 27.0"))

    def test_unavailable_and_future_runtime_ignored(self):
        d = {"devices": {IOS_272: [device("iPhone 18 Pro", B, False), device("iPhone 17", A)], IOS_273: [device("iPhone 17", D)]}}
        self.assertEqual(choose(d, "27.2"), (A, "iPhone 17", "iOS 27.2"))

    def test_no_ios_26_or_duo_fallback(self):
        d = {"devices": {IOS_262: [device("iPhone 17", A)], IOS_271: [device("iPhone Duo", D)]}}
        with self.assertRaisesRegex(ValueError, "No available standard iPhone"):
            choose(d, "27.2")

    def test_old_sdk_rejected(self):
        with self.assertRaisesRegex(ValueError, "Expected an iOS 27"):
            choose({"devices": {}}, "26.5")


if __name__ == "__main__":
    unittest.main()
