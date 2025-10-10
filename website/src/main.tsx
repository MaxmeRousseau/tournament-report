import ReactDOM from "react-dom/client"
import { BrowserRouter, Route, Routes } from "react-router"
import './index.css'
import BasePage from "./pages/BasePage"

const root = document.getElementById('root') as HTMLElement

ReactDOM.createRoot(root).render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<BasePage />} />
    </Routes>
  </BrowserRouter>
)
