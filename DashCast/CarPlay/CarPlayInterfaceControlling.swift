import CarPlay

/// The subset of `CPInterfaceController` that `CarPlaySceneDelegate` uses.
///
/// `CPInterfaceController` cannot be created outside a real CarPlay session, so the scene
/// delegate talks to this protocol instead. Production passes the real controller (see the
/// conformance below); tests pass an in-memory mock that records the template stack.
@MainActor
public protocol CarPlayInterfaceControlling: AnyObject {
    var templates: [CPTemplate] { get }
    var topTemplate: CPTemplate? { get }
    func carPlaySetRoot(_ template: CPTemplate, animated: Bool)
    func carPlayPush(_ template: CPTemplate, animated: Bool)
    func carPlayPop(to template: CPTemplate, animated: Bool)
    func carPlayPopToRoot(animated: Bool, completion: (() -> Void)?)
}

extension CPInterfaceController: CarPlayInterfaceControlling {
    public func carPlaySetRoot(_ template: CPTemplate, animated: Bool) {
        setRootTemplate(template, animated: animated, completion: nil)
    }

    public func carPlayPush(_ template: CPTemplate, animated: Bool) {
        pushTemplate(template, animated: animated, completion: nil)
    }

    public func carPlayPop(to template: CPTemplate, animated: Bool) {
        pop(to: template, animated: animated, completion: nil)
    }

    public func carPlayPopToRoot(animated: Bool, completion: (() -> Void)?) {
        popToRootTemplate(animated: animated) { _, _ in completion?() }
    }
}
