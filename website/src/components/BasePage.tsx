import { Outlet } from "react-router";
import { useEffect, useState } from "react";

function logout(setIsConnected: (value: boolean) => void) {
  localStorage.removeItem("access_token");
  localStorage.removeItem("refresh_token");
  setIsConnected(false);
  window.location.reload();
}

function login() {
  window.location.href = process.env.DISCORD_CONNECT_LINK || "";
}

function BasePage() {
  const [isConnected, setIsConnected] = useState<boolean>(() => {
    return !!localStorage.getItem("access_token");
  });

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const accessToken = params.get("access_token");
    const refreshToken = params.get("refresh_token");

    if (accessToken) {
      localStorage.setItem("access_token", accessToken);
      setIsConnected(true);
    }
    if (refreshToken) {
      localStorage.setItem("refresh_token", refreshToken);
    }

    if (accessToken || refreshToken) {
      // Nettoyer l'URL
      const newUrl = window.location.origin + window.location.pathname;
      window.history.replaceState({}, document.title, newUrl);
    }
  }, []);

  return (
    <div>
      <nav className="bg-gray-900">
        <div className="p0 pt-1 pl-1 flex items-center">
          <ul className="flex space-x-4">
            {/* ... éléments ... */}
          </ul>

          {isConnected ? (
            <button className="btn-gradient group ml-auto cursor-pointer" onClick={() => logout(setIsConnected)}>
              <span className="btn-gradient-inner">
                Déconnexion
              </span>
            </button>
          ) : (
            <button className="btn-gradient ml-auto group cursor-pointer" onClick={login}>
              <span className="btn-gradient-inner">
                Connexion
              </span>
            </button>
          )}
        </div>
      </nav>
      <Outlet />
    </div>
  );
}

export default BasePage;