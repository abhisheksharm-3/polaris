/** Real code the ui class once flagged wrongly: each line here is correct. */
export function Shell({ onToggle }: { onToggle: () => void }) {
  return (
    <main className="min-h-screen supports-[height:100dvh]:min-h-[100dvh] max-h-screen">
      <meta name="viewport" content="width=device-width, maximum-scale=1.5" />
      <div role="button" tabIndex={0} onClick={onToggle} onKeyDown={onToggle}>
        Menu
      </div>
    </main>
  );
}
