export function totalCents(prices: number[]): number {
  let sum = 0;
  for (const price of prices) {
    sum += price; // accumulate
  }
  return sum;
}
