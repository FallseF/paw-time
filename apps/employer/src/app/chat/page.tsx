import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { ChatPage } from "../../features/chat/ChatPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <ChatPage />
    </Suspense>
  );
}
