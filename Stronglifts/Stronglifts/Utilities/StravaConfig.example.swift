// Copy this file to StravaConfig.swift and fill in your credentials.
// Create a Strava API app at https://www.strava.com/settings/api
// Set Authorization Callback Domain to: strava-callback

enum StravaConfig {
    static let clientID     = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"
    static let redirectURI  = "stronglifts://strava-callback"
    static let scope        = "activity:write"
}
