/** A card that opens its detail view. */
export function Card({ onOpen }: { onOpen: () => void }) {
  return (
    <section className="min-h-[100dvh] transition-transform">
      <button className="outline-none focus-visible:ring-2" onClick={onOpen}>
        Open
      </button>
    </section>
  );
}
