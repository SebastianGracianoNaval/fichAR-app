"use client";

import { motion } from "framer-motion";
import { ForgotPasswordForm } from "@/components/features/auth/forgot-password-form";

export default function ForgotPasswordPage() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      className="w-full max-w-md"
    >
      <ForgotPasswordForm />
    </motion.div>
  );
}
