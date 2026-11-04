import * as React from "react"
import { cn } from "cn"

function Card({ className, ...props }: React.ComponentProps<"section">) {
  return <section data-slot="card" className={cn("rounded-xl bg-card text-card-foreground ring-1 ring-foreground/10", className)} {...props} />
}

function CardHeader({ className, ...props }: React.ComponentProps<"header">) {
  return <header data-slot="card-header" className={cn("grid gap-1 px-4 pt-4", className)} {...props} />
}

function CardTitle({ className, ...props }: React.ComponentProps<"h2">) {
  return <h2 data-slot="card-title" className={cn("text-base font-semibold", className)} {...props} />
}

function CardDescription({ className, ...props }: React.ComponentProps<"p">) {
  return <p data-slot="card-description" className={cn("text-sm text-muted-foreground", className)} {...props} />
}

function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div data-slot="card-content" className={cn("p-4", className)} {...props} />
}

export { Card, CardHeader, CardTitle, CardDescription, CardContent }
