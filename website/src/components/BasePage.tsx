import { Outlet } from "react-router";

function BasePage() {
  return (
    <div>
      <nav className="bg-gray-900">
        <div className="p0 pt-1 pl-1 flex items-center">
          <ul className="flex space-x-4">
            {/* ... éléments ... */}
          </ul>

          <a href="https://discord.com/oauth2/authorize?client_id=1427616121095323669&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fapi%2Fauth%2Fcallback&scope=identify">
            <button className="btn-gradient group ml-auto">
              <span className="btn-gradient-inner">
                Login
              </span>
            </button>
          </a>
        </div>
      </nav>
      <Outlet />
    </div>
  );
}

export default BasePage;