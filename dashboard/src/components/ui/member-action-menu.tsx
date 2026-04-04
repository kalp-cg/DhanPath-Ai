"use client";

import * as React from "react";
import { AnimatePresence, motion } from "motion/react";
import { MoreVertical, ShieldCheck, UserMinus, X, Check } from "lucide-react";

type MemberActionMenuProps = {
  canTransferAdmin: boolean;
  canRemoveMember: boolean;
  transferLabel: string;
  onTransferAdmin: () => void;
  onRemoveMember: () => void;
};

export default function MemberActionMenu({
  canTransferAdmin,
  canRemoveMember,
  transferLabel,
  onTransferAdmin,
  onRemoveMember,
}: MemberActionMenuProps) {
  const [open, setOpen] = React.useState(false);
  const [confirmRemove, setConfirmRemove] = React.useState(false);
  const [openUpwards, setOpenUpwards] = React.useState(false);
  const rootRef = React.useRef<HTMLDivElement>(null);
  const popoverRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    const onPointerDown = (event: MouseEvent) => {
      if (!rootRef.current) return;
      if (!rootRef.current.contains(event.target as Node)) {
        setOpen(false);
        setConfirmRemove(false);
      }
    };

    const onEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        setConfirmRemove(false);
      }
    };

    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onEscape);

    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onEscape);
    };
  }, []);

  React.useEffect(() => {
    if (!open) return;

    const updateDirection = () => {
      const rootRect = rootRef.current?.getBoundingClientRect();
      if (!rootRect) return;

      const popoverHeight = popoverRef.current?.offsetHeight ?? 240;
      const spaceBelow = window.innerHeight - rootRect.bottom;
      const spaceAbove = rootRect.top;
      const shouldOpenUp = spaceBelow < popoverHeight + 16 && spaceAbove > spaceBelow;

      setOpenUpwards(shouldOpenUp);
    };

    updateDirection();
    window.addEventListener("resize", updateDirection);
    window.addEventListener("scroll", updateDirection, true);

    return () => {
      window.removeEventListener("resize", updateDirection);
      window.removeEventListener("scroll", updateDirection, true);
    };
  }, [open, confirmRemove]);

  const showMenu = canTransferAdmin || canRemoveMember;
  if (!showMenu) return null;

  return (
    <div ref={rootRef} className="wm-inline-menu">
      <button
        type="button"
        className="wm-inline-menu-trigger"
        aria-label="Open member actions"
        onClick={() => {
          setOpen((prev) => !prev);
          if (open) setConfirmRemove(false);
        }}
      >
        <MoreVertical size={18} />
      </button>

      <AnimatePresence>
        {open && (
          <motion.div
            ref={popoverRef}
            className={`wm-inline-menu-popover ${openUpwards ? "wm-inline-menu-popover--up" : ""}`}
            initial={{ opacity: 0, scale: 0.95, y: -6 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: -4 }}
            transition={{ type: "spring", duration: 0.28, bounce: 0 }}
          >
            <div className="wm-inline-menu-header">Member Actions</div>

            {!confirmRemove && (
              <div className="wm-inline-menu-list">
                {canTransferAdmin && (
                  <button
                    type="button"
                    className="wm-inline-menu-item"
                    onClick={() => {
                      onTransferAdmin();
                      setOpen(false);
                    }}
                  >
                    <ShieldCheck size={16} />
                    <span>{transferLabel}</span>
                  </button>
                )}

                {canRemoveMember && (
                  <button
                    type="button"
                    className="wm-inline-menu-item wm-inline-menu-item--danger"
                    onClick={() => setConfirmRemove(true)}
                  >
                    <UserMinus size={16} />
                    <span>Remove Member</span>
                  </button>
                )}
              </div>
            )}

            {confirmRemove && (
              <motion.div
                className="wm-inline-menu-confirm"
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 6 }}
                transition={{ duration: 0.2 }}
              >
                <p>Remove this member from family workspace?</p>
                <div className="wm-inline-menu-confirm-actions">
                  <button
                    type="button"
                    className="wm-inline-menu-confirm-btn wm-inline-menu-confirm-btn--cancel"
                    onClick={() => setConfirmRemove(false)}
                  >
                    <X size={14} />
                    <span>Cancel</span>
                  </button>
                  <button
                    type="button"
                    className="wm-inline-menu-confirm-btn wm-inline-menu-confirm-btn--danger"
                    onClick={() => {
                      onRemoveMember();
                      setOpen(false);
                      setConfirmRemove(false);
                    }}
                  >
                    <Check size={14} />
                    <span>Yes, Remove</span>
                  </button>
                </div>
              </motion.div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
