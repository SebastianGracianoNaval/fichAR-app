"use client";

import { motion } from "framer-motion";
import { LoginForm } from "@/components/features/auth/login-form";

export default function LoginPage() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: "easeOut" }}
      className="w-full max-w-md"
    >
      <LoginForm />
    </motion.div>
  );
}
