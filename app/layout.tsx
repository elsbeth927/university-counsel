import type {Metadata} from "next";import "./globals.css";
export const metadata:Metadata={title:"Redbridge Individual Learning Pathway",description:"Индивидуальная траектория ученика — Redbridge International School",other:{"codex-preview":"development"}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="ru"><body>{children}</body></html>}
