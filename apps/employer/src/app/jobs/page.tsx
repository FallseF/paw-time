import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { JobsPage } from "../../features/job-postings/JobsPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <JobsPage />
    </Suspense>
  );
}
