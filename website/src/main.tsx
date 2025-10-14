import ReactDOM from "react-dom/client"
import { BrowserRouter, Route, Routes } from "react-router"
import './index.css'
import BasePage from "./components/BasePage"
import Home from "./pages/Home"

const root = document.getElementById('root') as HTMLElement

ReactDOM.createRoot(root).render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<BasePage />}>
        <Route index element={<Home />} />
      </Route>
    </Routes>
  </BrowserRouter>
)
