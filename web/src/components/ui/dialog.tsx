"use client"

import * as React from "react"
import { Dialog as DialogPrimitive } from "radix-ui"
import { cn } from "cn"
import { X } from "lucide-react"
import { Button } from "@/components/ui/button"

function Dialog(props: React.ComponentProps<typeof DialogPrimitive.Root>) {
  return <DialogPrimitive.Root data-slot="dialog" {...props} />
}
function DialogTrigger(props: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...props} />
}
function DialogClose(props: React.ComponentProps<typeof DialogPrimitive.Close>) {
  return <DialogPrimitive.Close data-slot="dialog-close" {...props} />
}
function DialogContent({ className, children, showCloseButton = true, ...props }: React.ComponentProps<typeof DialogPrimitive.Content> & { showCloseButton?: boolean }) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/45 backdrop-blur-[2px]" />
      <DialogPrimitive.Content data-slot="dialog-content" className={cn("fixed top-1/2 left-1/2 z-50 grid max-h-[calc(100dvh-2rem)] w-[min(30rem,calc(100%-2rem))] -translate-x-1/2 -translate-y-1/2 gap-4 overflow-y-auto overscroll-contain rounded-xl bg-popover p-5 text-popover-foreground ring-1 ring-white/12 outline-none focus-visible:ring-2 focus-visible:ring-ring", className)} {...props}>
        {children}
        {showCloseButton ? <DialogPrimitive.Close asChild><Button className="absolute top-3 right-3" size="icon-sm" variant="ghost" aria-label="Fechar diálogo"><X /></Button></DialogPrimitive.Close> : null}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  )
}
function DialogHeader({ className, ...props }: React.ComponentProps<"header">) {
  return <header className={cn("grid gap-1 pr-8", className)} {...props} />
}
function DialogTitle({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return <DialogPrimitive.Title className={cn("text-lg font-semibold", className)} {...props} />
}
function DialogDescription({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return <DialogPrimitive.Description className={cn("text-sm leading-relaxed text-muted-foreground", className)} {...props} />
}
function DialogFooter({ className, ...props }: React.ComponentProps<"footer">) {
  return <footer className={cn("flex justify-end gap-2 border-t border-border pt-4", className)} {...props} />
}

export { Dialog, DialogTrigger, DialogClose, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter }
