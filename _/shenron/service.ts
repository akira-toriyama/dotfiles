import * as service from "../_/service.ts";

export const getShenronRoot = () =>
    [service.getChezmoiRoot(), "/_/shenron"].join("");
