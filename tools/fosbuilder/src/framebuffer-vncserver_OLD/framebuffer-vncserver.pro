TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

SOURCES += framebuffer-vncserver.c
SOURCES += keyboard.c
SOURCES += touch.c

include(deployment.pri)
qtcAddDeployment()


LIBS += -lvncserver

DISTFILES += \
    README.md
