"""Opening affordability baseline at 1d69565. Run: python scripts/qa/flow_opening.py

Only the first workshop and manual trips, not chapter/retention simulation.
Clock starts after the choice. Always tap after 0.6 s, checked on a 0.25 s grid;
retain all cash, no purchases, staff, daily claims, boosts, ads or special orders.
Prices, capacities, demand memory and durations mirror FlowContent/FlowSim.
"""

STARTS = {  # starting cash, batch, shelf, contacts in descending price order
    "cashbox": (60, 1, 20, [(10, 5)]),
    "addressBook": (0, 1, 20, [(8, 7.5), (10, 5)]),
    "tools": (0, 3, 40, [(10, 5)]),
}


def opening(start):
    cash, batch, capacity, contacts = STARTS[start]
    demand = [0.0] * len(contacts)
    stock = load = 0.0
    bench = trip = None
    ready_bench = ready_trip = None
    receipt = None
    affordable = 0.0 if cash >= 20 else None
    for quarter in range(120 * 4):
        t = quarter / 4
        if bench is None and stock < capacity:
            if ready_bench is None:
                ready_bench = t + 0.6
            if t >= ready_bench:
                bench, ready_bench = 5.0, None
        if trip is None and stock >= 1:
            if ready_trip is None:
                ready_trip = t + 0.6
            if t >= ready_trip and sum(demand) > 0:
                load = min(1.0, stock, sum(demand))
                stock -= load
                trip, ready_trip = 10.0, None

        for i, (rate, _) in enumerate(contacts):
            demand[i] = min(2 * rate, demand[i] + rate * 0.25 / 60)
        if bench is not None:
            bench -= 0.25
            if bench == 0:
                stock = min(capacity, stock + batch)
                bench = None
        if trip is not None:
            trip -= 0.25
            if trip == 0:
                for i, (_, price) in enumerate(contacts):
                    sold = min(load, demand[i])
                    demand[i] -= sold
                    load -= sold
                    cash += sold * price
                stock = min(capacity, stock + load)
                trip = None
                if receipt is None:
                    receipt = t + 0.25
                if affordable is None and cash >= 20:
                    affordable = t + 0.25
        if receipt is not None and affordable is not None:
            return receipt, affordable
    raise RuntimeError(f"No first receipt or affordable van upgrade within 120 s: {start}")


if __name__ == "__main__":
    for name, expected in (("cashbox", 0), ("addressBook", 38), ("tools", 48.75)):
        booked, affordable = opening(name)
        print(f"{name}: first booking {booked:g} s; 20 cash available {affordable:g} s")
        assert (booked, affordable) == (16.5, expected)
