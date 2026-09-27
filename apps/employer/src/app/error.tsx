"use client";

import { Empty } from "../components/ui";

export default function ErrorPage({ reset }: { error: Error; reset: () => void }) {
  const ja = typeof document !== "undefined" && document.documentElement.lang === "ja";
  return (
    <Empty
      icon="alert"
      title={ja ? "問題が起きました" : "Something went wrong"}
      body={ja ? "このページを読み込めませんでした。ほかのページでの変更は残っています。" : "This page couldn't load. Your changes on other pages are kept."}
      action={<button type="button" className="btn" onClick={reset}>{ja ? "もう一度" : "Try again"}</button>}
    />
  );
}
