"use client";

import { motion } from "framer-motion";
import { SetPasswordForm } from "@/components/features/auth/set-password-form";

export default function SetPasswordPage() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: "easeOut" }}
      className="w-full max-w-md"
    >
      <SetPasswordForm />
    </motion.div>
  );
}
