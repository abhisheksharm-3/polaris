import { total } from '../src/total';

describe('total', () => {
  it('rounds half-cent amounts up, as the invoice rule requires', () => {
    expect(total([0.005, 0.005])).toBe(0.01);
  });
  it.skip('applies the 2027 tax table (reason: table ships 2027-01-01, expires 2027-01-15)', () => {});
});
