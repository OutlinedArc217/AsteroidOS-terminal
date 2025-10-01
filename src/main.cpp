/*
 * Copyright (C) 2024 - AsteroidOS Terminal
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickView>
#include <QQmlContext>
#include <QProcess>
#include <QTimer>
#include <QDebug>
#include <QScreen>

int main(int argc, char *argv[])
{
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    
    app.setApplicationName("Terminal");
    app.setApplicationDisplayName("Terminal");
    app.setOrganizationName("AsteroidOS");
    app.setOrganizationDomain("asteroidos.org");
    
    QQuickView view;
    
    // Set up the view
    view.setSource(QUrl("qrc:/main.qml"));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setColor(Qt::black);
    
    // Get screen geometry
    QScreen *screen = QGuiApplication::primaryScreen();
    QRect screenGeometry = screen->geometry();
    
    // Make window full screen
    view.setGeometry(screenGeometry);
    view.showFullScreen();
    
    return app.exec();
}