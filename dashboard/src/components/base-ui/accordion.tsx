"use client";

import * as React from "react";

type AccordionContextValue = {
  type: "single" | "multiple";
  openValues: string[];
  toggle: (value: string) => void;
};

const AccordionContext = React.createContext<AccordionContextValue | null>(null);

type AccordionProps = {
  type?: "single" | "multiple";
  defaultValue?: string[];
  className?: string;
  children: React.ReactNode;
};

export function Accordion({
  type = "multiple",
  defaultValue = [],
  className,
  children,
}: AccordionProps) {
  const [openValues, setOpenValues] = React.useState<string[]>(defaultValue);

  const toggle = React.useCallback(
    (value: string) => {
      setOpenValues((prev) => {
        const isOpen = prev.includes(value);
        if (type === "single") {
          return isOpen ? [] : [value];
        }
        if (isOpen) {
          return prev.filter((v) => v !== value);
        }
        return [...prev, value];
      });
    },
    [type],
  );

  return (
    <AccordionContext.Provider value={{ type, openValues, toggle }}>
      <div className={className}>{children}</div>
    </AccordionContext.Provider>
  );
}

type AccordionItemProps = {
  value: string;
  className?: string;
  children: React.ReactNode;
};

const AccordionItemContext = React.createContext<{ value: string } | null>(null);

export function AccordionItem({ value, className, children }: AccordionItemProps) {
  return (
    <AccordionItemContext.Provider value={{ value }}>
      <div className={className}>{children}</div>
    </AccordionItemContext.Provider>
  );
}

type AccordionTriggerProps = {
  className?: string;
  children: React.ReactNode;
};

export function AccordionTrigger({ className, children }: AccordionTriggerProps) {
  const accordion = React.useContext(AccordionContext);
  const item = React.useContext(AccordionItemContext);

  if (!accordion || !item) {
    return null;
  }

  const isOpen = accordion.openValues.includes(item.value);

  return (
    <button
      type="button"
      className={className}
      aria-expanded={isOpen}
      data-state={isOpen ? "open" : "closed"}
      onClick={() => accordion.toggle(item.value)}
    >
      <span data-slot="accordion-trigger-label" style={{ minWidth: 0, flex: 1 }}>
        {children}
      </span>
      <span data-slot="accordion-trigger-icon" aria-hidden="true">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="m9 6 6 6-6 6" />
        </svg>
      </span>
    </button>
  );
}

type AccordionContentProps = {
  className?: string;
  children: React.ReactNode;
};

export function AccordionContent({ className, children }: AccordionContentProps) {
  const accordion = React.useContext(AccordionContext);
  const item = React.useContext(AccordionItemContext);

  if (!accordion || !item) {
    return null;
  }

  const isOpen = accordion.openValues.includes(item.value);
  if (!isOpen) return null;

  return <div className={className}>{children}</div>;
}
