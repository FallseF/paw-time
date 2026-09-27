import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { PayrollPage } from "../../features/payroll/PayrollPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <PayrollPage />
    </Suspense>
  );
}
