import { Card, CardContent, CardHeader } from "@/components/ui/card";

export default function OrganizationsLoading() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-2">
          <div className="h-8 w-48 animate-pulse rounded bg-muted" />
          <div className="h-4 w-64 animate-pulse rounded bg-muted" />
        </div>
        <div className="h-10 w-40 animate-pulse rounded bg-muted" />
      </div>
      <Card>
        <CardHeader>
          <div className="h-6 w-24 animate-pulse rounded bg-muted" />
          <div className="mt-2 h-4 w-48 animate-pulse rounded bg-muted" />
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="h-10 w-64 animate-pulse rounded bg-muted" />
          <div className="space-y-3">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="h-12 animate-pulse rounded-lg bg-muted" />
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
