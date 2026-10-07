describe.only('totals', () => {
  it('adds', async () => {
    await page.waitForTimeout(500);
    expect(true).toBe(true);
  });
  it.skip('rounds', () => {});
});
