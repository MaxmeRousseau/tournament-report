import { Outlet } from "react-router";

function BasePage() {
  return (
    <div>
      <nav className="bg-gray-900">
        <div className="p0 pt-1 pl-1 flex items-center">
          <ul className="flex space-x-4">
            {/* ... éléments ... */}
          </ul>

          <button className="btn-gradient group ml-auto">
            <span className="btn-gradient-inner">
              Login
            </span>
          </button>
        </div>
      </nav>
      <Outlet />
    </div>
  );
}

export default BasePage;