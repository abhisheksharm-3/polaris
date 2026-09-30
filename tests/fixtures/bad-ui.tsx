export function Card({ onOpen }: { onOpen: () => void }) {
  return (
    <div className="min-h-screen transition-all outline-none" onClick={onOpen}>
      <input onPaste={(e) => e.preventDefault()} />
    </div>
  );
}
