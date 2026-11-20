"""Select the estate pickup price before changing Flow. Run with Python 3.

The pickup is at the door (one deliberate handover, no simulation clock).
Then choose an heirloom and buy one ordinary wagon level. Report cash after
confirmed purchase, not a predicted human tap time. The previous model starts
later, after inheritance, with manual production and transport already open.
"""
from flow_opening import STARTS, opening

VAN_COST = 20


def trial(start, ticket):
    cash = ticket + STARTS[start][0]
    if cash < VAN_COST:
        return None
    return cash - VAN_COST


if __name__ == '__main__':
    candidates = [5, 10, 15, 20, 25]
    for ticket in candidates:
        result = [trial(start, ticket) for start in STARTS]
        print(f'pickup {ticket}: wallet after paid van upgrade {result} (None: unaffordable)')
    smallest = min(v for v in candidates if all(trial(s, v) is not None for s in STARTS))
    assert smallest == VAN_COST and [trial(s, smallest) for s in STARTS] == [60, 0, 0]
    for start in STARTS:
        booked, affordable = opening(start)
        print(f'{start}: baseline booking {booked:g}s, affordability {affordable:g}s; '
              f'candidate: handover books {smallest}; no production wait before upgrade')
