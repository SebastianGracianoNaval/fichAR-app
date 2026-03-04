import { getStatsAction } from "./actions";
import { DashboardContent } from "./dashboard-content";

/**
 * Dashboard: Server Component. Datos iniciales (stats) se obtienen en el servidor
 * para mejor FCP y menos JS en el cliente (T16 / Step 15).
 */
export default async function DashboardPage() {
  const result = await getStatsAction();
  const initialStats = result.ok ? result.data : null;

  return <DashboardContent initialStats={initialStats} />;
}
