import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { ApplicantsPage } from "../../features/applicants/ApplicantsPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <ApplicantsPage />
    </Suspense>
  );
}
