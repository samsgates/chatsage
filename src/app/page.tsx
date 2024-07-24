import { Header } from "@/components/header";
import { createClient } from "@/lib/supabase/server";
import Link from "next/link";
import Script from "next/script";

export default async function Home() {
  let isLoggedIn = false;
  const supabase = createClient();
  const { data } = await supabase.auth.getUser();

  if (data?.user) isLoggedIn = true;

  return (
    <>
      <Header isLoggedIn={isLoggedIn} />
      <main className="flex-1">
        <header>
          <Link href="/dashboard">dashboard</Link>
        </header>
        <h1>SupaChat</h1>
        <Script async defer src="/widget.js" />
      </main>
    </>
  );
}
