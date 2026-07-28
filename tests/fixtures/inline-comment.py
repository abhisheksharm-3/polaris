def total_cents(prices):
    total = 0
    for price in prices:
        total += price  # accumulate
    return total
