"use client";

import { Input } from "@/components/ui/input";
import { SitemapButton } from "./sitemap-button";
import { useFormState } from "react-dom";
import { findSites } from "@/actions/find-sites";
import { DataTable } from "@/components/ui/data-table";
import { useEffect, useState } from "react";
import { scrape } from "@/actions/scrape";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { statusColumns } from "./status-columns";
import { sourceListColumns } from "./source-list-columns";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useChatbotInternalId } from "@/lib/hooks/use-chatbot-internal-id";

const initialState = {
  sites: [],
};

export const SitemapForm = () => {
  const supabase = createClient();
  const router = useRouter();
  const chatbotInternalId = useChatbotInternalId();

  const [scraping, setScraping] = useState(false);
  const [selectedRows, setSelectedRows] = useState<string[]>([]);
  const [scrapingInitiated, setScrapingInitiated] = useState(false);
  const [state, formAction] = useFormState(findSites, initialState);
  const [scrapingStatus, setScrapingStatus] = useState<
    { url: string; status: string }[]
  >([]);
  const [showTable, setShowTable] = useState(true);

  const handleSelectionChange = (newSelectedRows: string[]) => {
    setSelectedRows(newSelectedRows);
  };

  useEffect(() => {
    const cloned = [...selectedRows];

    setScrapingStatus(
      cloned.map((c) => {
        return {
          url: c,
          status: "Waiting",
        };
      })
    );
  }, [selectedRows]);

  if (state.success === false) {
    toast.error("URL is required");
  }

  return (
    <>
      <form className="flex w-full items-center gap-2" action={formAction}>
        <Input
          type="url"
          name="url"
          id="url"
          className="flex-1"
          placeholder="htttps://www.yourdomain.com/sitemap.xml"
        />
        <SitemapButton />
      </form>
      {showTable && state.sites.length > 0 && (
        <div className="mt-10">
          <div className="mb-4 flex items-center gap-x-4">
            <div className="text-xl font-bold">Found sources</div>
            <form
              onSubmit={async (e) => {
                e.preventDefault();

                setScrapingInitiated(true);

                for (const site of selectedRows) {
                  console.log(`scraping ${site}...`);

                  setScrapingStatus((prev) => {
                    const cloned = [...prev];

                    const index = cloned.findIndex((item) => item.url === site);
                    if (index !== -1) {
                      cloned[index].status = "Processing...";
                    }

                    return cloned;
                  });

                  const result = await scrape(site);
                  if (!result.success) {
                    toast.error(result.message, { duration: 7000 });
                    setShowTable(false);
                    router.refresh();

                    return;
                  }

                  setScrapingStatus((prev) => {
                    const cloned = [...prev];

                    const index = cloned.findIndex((item) => item.url === site);
                    if (index !== -1) {
                      cloned[index].status = "Done";
                    }

                    return cloned;
                  });

                  await supabase
                    .from("urls")
                    .update({
                      status: "done",
                    })
                    .match({
                      url: site,
                      chatbot_internal_id: chatbotInternalId,
                    });
                }

                router.refresh();
              }}
            >
              <Button
                size="sm"
                type="submit"
                disabled={
                  scraping || selectedRows.length === 0 || scrapingInitiated
                }
              >
                Scrape the selected sources
              </Button>
            </form>
          </div>
          {scrapingInitiated ? (
            <DataTable
              columns={statusColumns}
              data={scrapingStatus}
              onSelectionChange={handleSelectionChange}
            />
          ) : (
            <DataTable
              columns={sourceListColumns}
              data={state.sites.map((site) => ({ url: site }))}
              onSelectionChange={handleSelectionChange}
            />
          )}
        </div>
      )}
    </>
  );
};
