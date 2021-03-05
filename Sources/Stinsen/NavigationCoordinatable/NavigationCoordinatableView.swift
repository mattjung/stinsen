import Foundation
import SwiftUI
import Combine

struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    var children: Children
    private let id: Int
    @EnvironmentObject private var root: RootCoordinator
    private let router: NavigationRouter<T>
    private let start: AnyView
    @ObservedObject var presentationHelper: PresentationHelper<T>
    
    var body: some View {
        self.start
            .background(
                NavigationLink(
                    destination: { () -> AnyView in
                        if let view = presentationHelper.presented?.view {
                            return AnyView(view.environmentObject(root))
                        } else {
                            return AnyView(EmptyView())
                        }
                    }(),
                    isActive: Binding<Bool>.init(get: { () -> Bool in
                        return presentationHelper.presented?.isPush == true
                    }, set: { _ in
                             
                    }),
                    label: {
                        EmptyView()
                    }
                )
                .hidden()
            )
            .onAppear(perform: {
                self.router.root = root.coordinator
                /*
                 alerternate version:
                if self.id == -1 {
                    if self.router.root == nil {
                        self.router.root = root.coordinator
                    }
                }*/

                // Set the appear variable. This will be checked later in onDisappear.
                self.coordinator.navigationStack.appearing = id
            })
            .onDisappear(perform: {
                // Find the appearing coordinator
                guard let appearingCoordinator = self.root.coordinator.children.allChildren.first(where: {
                    return $0.appearingMetadata?.appearing != nil
                }) else {
                    return
                }
                
                if appearingCoordinator.id == self.coordinator.id {
                    let appearing = coordinator.navigationStack.appearing!
                    // We are popping on the same stack
                    if appearing < id {
                        self.coordinator.navigationStack.popTo(appearing)
                    }
                } else {
                    // Popping on another stack
                    let stack = appearingCoordinator.appearingMetadata!
                    stack.popTo(stack.appearing!)
                    
                    DispatchQueue.main.async {
                        appearingCoordinator.children.onChildDismiss()
                        appearingCoordinator.children.onChildDismiss = {}
                    }
                }
            })
            .sheet(isPresented: Binding<Bool>.init(get: { () -> Bool in
                return presentationHelper.presented?.isModal == true
            }, set: { _ in
            
            }), onDismiss: {
                // shouldn't matter if different coordinators. also this set modal children to nil
                self.coordinator.navigationStack.popTo(self.id)
                
                DispatchQueue.main.async {
                    self.children.onModalChildDismiss()
                    self.children.onModalChildDismiss = {}
                }
            }, content: { () -> AnyView in
                return { () -> AnyView in
                    if let view = presentationHelper.presented?.view {
                        return AnyView(view.environmentObject(root))
                    } else {
                        return AnyView(EmptyView())
                    }
                }()
            })
            .environmentObject(router)
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        self.children = coordinator.children
        
        self.presentationHelper = PresentationHelper(
            id: self.id,
            coordinator: coordinator
        )
        
        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator
        )
        
        if let presentation = coordinator.navigationStack.value[safe: id] {
            if let view = coordinator.resolveRoute(route: presentation.route).presentable as? AnyView {
                self.start = view
            } else {
                fatalError("Can only show views")
            }
        } else if id == -1 {
            self.start = AnyView(
                coordinator
                    .start()
            )
        } else {
            fatalError()
        }
    }
}
