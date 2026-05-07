import { Loader2 } from "lucide-react";

export function LoadingSpinner({ size = 24 }: { size?: number }) {
  return (
    <div className="flex items-center justify-center w-full py-12">
      <Loader2 className="animate-spin text-zinc-500" size={size} />
    </div>
  );
}

export function InlineSpinner() {
  return <Loader2 className="animate-spin inline w-4 h-4" />;
}
