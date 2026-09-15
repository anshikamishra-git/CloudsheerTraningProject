public class HiringServiceException extends Exception {
/**
 * Contract:
 * Inputs: none (constructed with a message string)
 * Outputs: n/a (exception instance)
 * Side effects: none
 * Sharing mode: n/a (exceptions don't carry sharing context)
 *
 * Purpose: Thrown by HiringService when input passed to a public
 * method is invalid (null/empty collections, missing required data).
 * Callers should catch this specifically to show a clean message
 * to the user, instead of leaking a generic system error.
 */
}