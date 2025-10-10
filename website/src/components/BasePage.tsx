import { Outlet } from "react-router";

function BasePage() {
  return (
    <div>
      <h1>Welcome to the Tournament Report</h1>
      <p>This is the base page of the application.</p>
      <Outlet />
    </div>
  );
}

export default BasePage;