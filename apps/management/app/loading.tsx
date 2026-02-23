export default function Loading() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background">
      <div
        className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
        role="status"
        aria-label="Cargando"
      />
      <p className="mt-4 text-sm text-muted-foreground">
        Cargando fichAR Management...
      </p>
    </div>
  );
}
