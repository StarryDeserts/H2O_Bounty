import type { Metadata } from "next"
import "./globals.css"
import { Inter } from "next/font/google"
import { ThemeProvider } from "@/components/theme-provider"
import Navbar from "./components/Navbar"
import { Providers } from "./provide"
import { Toaster } from "@/components/ui/toaster"

const inter = Inter({ subsets: ["latin"] })

export const metadata: Metadata = {
  title: "H2O Bounty",
  description: "A decentralized task management and bounty system",
  icons: {
    icon: [
      {
        url: "/icon.png",
        href: "/icon.png",
      }
    ],
    // 为了更好的兼容性，也可以添加其他尺寸
    apple: [
      {
        url: "/icon.png",
        sizes: "180x180",
        type: "image/png",
      }
    ],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={`min-h-screen bg-gradient-to-b from-[var(--h2o-softbg)] to-white ${inter.className}`}>
        <Providers>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            <div className="min-h-screen">
              <Navbar />
              <main className="container mx-auto px-4 py-8 animate-fadeIn">
                {children}
              </main>
            </div>
          </ThemeProvider>
        </Providers>
        <Toaster />
      </body>
    </html>
  )
}

