import type React from "react"
import type { Metadata, Viewport } from "next"
import { Work_Sans } from "next/font/google"
import "./globals.css"

const workSans = Work_Sans({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-work-sans",
})

export const metadata: Metadata = {
  title: "GastroGuard - Gastritis Tracker",
  description: "Track your gastritis symptoms, analyze triggers, and manage your digestive health",
  generator: "v0.app",
  manifest: "/manifest.json",
  keywords: ["gastritis", "health", "symptom tracker", "digestive health", "pain management"],
  authors: [{ name: "GastroGuard" }],
  creator: "GastroGuard",
  publisher: "GastroGuard",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  icons: {
    icon: "/icon-192x192.png",
    apple: "/icon-192x192.png",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "GastroGuard",
  },
}

export const viewport: Viewport = {
  themeColor: "#0891b2",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={workSans.variable}>
      <head>
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <meta name="apple-mobile-web-app-title" content="GastroGuard" />
        <meta name="mobile-web-app-capable" content="yes" />
        <link rel="apple-touch-icon" href="/icon-192x192.png" />
        <link rel="icon" type="image/png" sizes="192x192" href="/icon-192x192.png" />
        <link rel="icon" type="image/png" sizes="512x512" href="/icon-512x512.png" />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', function() {
                  navigator.serviceWorker.register('/sw.js')
                    .then(function(registration) {
                      console.log('SW registered: ', registration);
                      
                      registration.addEventListener('updatefound', () => {
                        const newWorker = registration.installing;
                        if (newWorker) {
                          newWorker.addEventListener('statechange', () => {
                            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                              // Show update notification
                              const updateBanner = document.createElement('div');
                              updateBanner.id = 'update-banner';
                              updateBanner.innerHTML = \`
                                <div style="position: fixed; top: 0; left: 0; right: 0; z-index: 9999; background: linear-gradient(135deg, rgba(8, 145, 178, 0.95), rgba(6, 182, 212, 0.95)); backdrop-filter: blur(20px); color: white; padding: 12px 16px; text-align: center; font-family: system-ui; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
                                  <div style="display: flex; align-items: center; justify-content: center; gap: 12px;">
                                    <span>🔄 New version available!</span>
                                    <button onclick="window.location.reload()" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3); color: white; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 14px;">Update Now</button>
                                    <button onclick="document.getElementById('update-banner').remove()" style="background: transparent; border: none; color: white; cursor: pointer; font-size: 18px; padding: 4px;">×</button>
                                  </div>
                                </div>
                              \`;
                              document.body.appendChild(updateBanner);
                            }
                          });
                        }
                      });
                    })
                    .catch(function(registrationError) {
                      console.log('SW registration failed: ', registrationError);
                    });
                });
              }
            `,
          }}
        />
      </head>
      <body className="font-sans antialiased">
        <div className="min-h-screen bg-background">{children}</div>
      </body>
    </html>
  )
}
