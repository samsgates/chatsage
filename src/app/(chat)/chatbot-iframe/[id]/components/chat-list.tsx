import { Separator } from "@/components/ui/separator";
import { UIState } from "../lib/chat/actions";

export interface ChatList {
  messages: UIState;
}

export function ChatList({ messages }: ChatList) {
  if (!messages.length) {
    return null;
  }

  return (
    <div className="relative mx-auto px-6 md:px-12">
      {messages.map((message, index) => (
        <div key={message.id}>
          {message.display}
          {index < messages.length - 1 && <Separator className="my-4" />}
        </div>
      ))}
    </div>
  );
}