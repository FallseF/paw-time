import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { ReviewsPage } from "../../features/reviews/ReviewsPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <ReviewsPage />
    </Suspense>
  );
}
