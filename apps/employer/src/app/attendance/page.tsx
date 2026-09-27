import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { ShiftsPage } from "../../features/attendance/ShiftsPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <ShiftsPage />
    </Suspense>
  );
}
