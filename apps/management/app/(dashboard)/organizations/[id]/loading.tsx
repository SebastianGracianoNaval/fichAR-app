import { Card, CardContent, CardHeader } from "@/components/ui/card";

export default function OrganizationDetailLoading() {
  return (
    <div className="space-y-6">
      <div className="h-10 w-32 animate-pulse rounded bg-muted" />
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="h-12 w-12 animate-pulse rounded-xl bg-muted" />
              <div className="space-y-2">
                <div className="h-6 w-40 animate-pulse rounded bg-muted" />
                <div className="h-4 w-48 animate-pulse rounded bg-muted" />
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="h-4 w-full animate-pulse rounded bg-muted" />
            <div className="h-4 w-3/4 animate-pulse rounded bg-muted" />
            <div className="h-4 w-1/2 animate-pulse rounded bg-muted" />
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <div className="h-6 w-24 animate-pulse rounded bg-muted" />
            <div className="mt-2 h-4 w-40 animate-pulse rounded bg-muted" />
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="h-10 w-full animate-pulse rounded bg-muted" />
            <div className="h-10 w-full animate-pulse rounded bg-muted" />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
